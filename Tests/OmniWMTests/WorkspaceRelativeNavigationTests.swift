// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import ApplicationServices
import Carbon
import Foundation
@testable import OmniWM
import OmniWMIPC
import TOML
import XCTest

@MainActor
final class WorkspaceRelativeNavigationTests: XCTestCase {
    private final class FocusRecorder {
        var focusedWindowIds: [UInt32] = []
    }

    @MainActor
    private struct Fixture {
        let controller: WMController
        let router: IPCCommandRouter
        let focusRecorder: FocusRecorder
        let monitorA: Monitor
        let monitorB: Monitor
        let workspace1: WorkspaceDescriptor.ID
        let workspace2: WorkspaceDescriptor.ID
        let workspace3: WorkspaceDescriptor.ID
        let workspace5: WorkspaceDescriptor.ID

        var manager: WorkspaceManager {
            controller.workspaceManager
        }

        var navigation: WorkspaceNavigationHandler {
            controller.workspaceNavigationHandler
        }
    }

    func testHotkeyActionsAreRegisteredUnassignedWithIPCCommands() throws {
        let cases: [(command: HotkeyCommand, id: String, title: String, ipcName: IPCCommandName)] = [
            (.workspace(.switchToNew), "switchWorkspace.new", "Switch to New Workspace", .workspace(.switchToNew)),
            (
                .workspace(.moveToNew),
                "moveToWorkspace.new",
                "Move Focused Window to New Workspace",
                .workspace(.moveToNew)
            ),
            (
                .workspace(.moveNext),
                "moveToWorkspace.next",
                "Move Focused Window to Next Workspace",
                .workspace(.moveNext)
            ),
            (
                .workspace(.movePrevious),
                "moveToWorkspace.previous",
                "Move Focused Window to Previous Workspace",
                .workspace(.movePrevious)
            )
        ]
        let defaults = HotkeyBindingRegistry.defaults()
        let resolvedWithoutEntries = try HotkeyBindingRegistry.resolve([])

        for entry in cases {
            let spec = try XCTUnwrap(ActionCatalog.spec(for: entry.command))
            XCTAssertEqual(spec.id, entry.id)
            XCTAssertEqual(spec.title, entry.title)
            XCTAssertEqual(spec.category, .workspace)
            XCTAssertEqual(spec.visibility, .normal)
            XCTAssertEqual(spec.layoutCompatibility, .shared)
            XCTAssertEqual(spec.defaultBinding, .unassigned)
            XCTAssertEqual(spec.ipcCommandName, entry.ipcName)
            XCTAssertNotNil(spec.ipcDescriptor)
            XCTAssertEqual(ActionCatalog.spec(for: entry.id), spec)
            XCTAssertEqual(HotkeyBindingRegistry.command(for: entry.id), entry.command)
            XCTAssertNil(WorkspaceNumberActionKind.parse(entry.id))
            XCTAssertEqual(defaults.first { $0.id == entry.id }?.binding, .unassigned)
            XCTAssertEqual(resolvedWithoutEntries.first { $0.id == entry.id }?.binding, .unassigned)
        }
    }

    func testSettingsWrittenBeforeTheseActionsKeepModeKeysOnTheirActionsWhenRewritten() throws {
        var export = SettingsExport.defaults()
        let modeKeys = [
            "focus.left": KeyBinding(keyCode: UInt32(kVK_ANSI_H), modifiers: 0),
            "toggleSystemStats": KeyBinding(keyCode: UInt32(kVK_ANSI_S), modifiers: 0)
        ]
        for (id, modeKey) in modeKeys {
            let index = try XCTUnwrap(export.hotkeyBindings.firstIndex { $0.id == id })
            export.hotkeyBindings[index].modeKey = modeKey
        }
        let newIDs: Set = [
            "switchWorkspace.new", "moveToWorkspace.new", "moveToWorkspace.next", "moveToWorkspace.previous"
        ]
        var tree = try TOMLDecoder().decode([String: TOMLNode].self, from: SettingsTOMLCodec.encode(export))
        guard case let .array(entries) = tree["hotkeys"] else { return XCTFail("Expected a hotkeys array") }
        tree["hotkeys"] = .array(entries.filter { entry in
            guard case let .table(table) = entry, case let .string(id) = table["id"] else { return true }
            return !newIDs.contains(id)
        })
        let encoder = TOMLEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let olderFile = try encoder.encode(tree)

        let loaded = try SettingsTOMLCodec.decode(olderFile)
        XCTAssertTrue(SettingsTOMLCodec.unknownKeyPaths(in: olderFile).isEmpty)
        for id in newIDs {
            XCTAssertEqual(loaded.hotkeyBindings.first { $0.id == id }?.binding, .unassigned, id)
        }
        let rewritten = try SettingsTOMLCodec.decode(
            SettingsTOMLCodec.encode(loaded, preservingUnknownKeysFrom: olderFile)
        )
        let rewrittenModeKeys = rewritten.hotkeyBindings.compactMap { binding in
            binding.modeKey.map { (binding.id, $0) }
        }
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: rewrittenModeKeys), modeKeys)
    }

    func testMoveToNewWorkspaceCreatesWorkspaceOnWindowMonitorAndFollowsWindow() throws {
        let fixture = try makeFixture()
        let manager = fixture.manager
        let configurations = fixture.controller.settings.workspaces.configurations
        let remaining = addWindow(to: fixture.workspace1, in: fixture, windowId: 12)
        let moved = addWindow(to: fixture.workspace1, in: fixture)

        let created = try LayoutRefreshTestSupport.withBlocked(
            fixture.controller, in: fixture.workspace1, reason: .workspaceTransition
        ) {
            XCTAssertTrue(fixture.navigation.moveFocusedWindowToNewWorkspace())
            let created = try XCTUnwrap(manager.workspaceId(named: "6"))
            try runPendingPostLayoutActions(in: fixture)
            return created
        }

        XCTAssertEqual(manager.monitorId(for: created), fixture.monitorA.id)
        XCTAssertEqual(manager.workspace(for: moved), created)
        XCTAssertEqual(manager.workspace(for: remaining), fixture.workspace1)
        XCTAssertEqual(manager.activeWorkspace(on: fixture.monitorA.id)?.id, created)
        XCTAssertEqual(manager.activeWorkspace(on: fixture.monitorB.id)?.id, fixture.workspace2)
        XCTAssertEqual(fixture.controller.activeWorkspace()?.id, created)
        XCTAssertEqual(fixture.focusRecorder.focusedWindowIds, [UInt32(moved.windowId)])
        XCTAssertEqual(fixture.controller.intentLedger.activeManagedRequest?.token, moved)
        XCTAssertEqual(fixture.controller.settings.workspaces.configurations, configurations)
    }

    func testMoveToNewWorkspaceUsesFocusedWindowMonitorOverInteractionMonitor() throws {
        let fixture = try makeFixture()
        let manager = fixture.manager
        let moved = addWindow(to: fixture.workspace2, in: fixture)
        _ = manager.setInteractionMonitor(fixture.monitorA.id)
        XCTAssertEqual(manager.selectedManagedToken, moved)
        defer { fixture.controller.layoutRefreshController.resetState() }

        XCTAssertTrue(fixture.navigation.moveFocusedWindowToNewWorkspace())

        let created = try XCTUnwrap(manager.workspaceId(named: "4"))
        XCTAssertEqual(manager.monitorId(for: created), fixture.monitorB.id)
        XCTAssertEqual(manager.workspace(for: moved), created)
        XCTAssertEqual(manager.activeWorkspace(on: fixture.monitorB.id)?.id, created)
        XCTAssertEqual(manager.activeWorkspace(on: fixture.monitorA.id)?.id, fixture.workspace1)
    }

    func testMoveToNewWorkspaceMovesFloatingWindowLikeNumberedMove() throws {
        let numbered = try makeFixture()
        let numberedToken = addWindow(to: numbered.workspace1, in: numbered, mode: .floating)
        defer { numbered.controller.layoutRefreshController.resetState() }
        numbered.navigation.moveFocusedWindow(toRawWorkspaceID: "3")
        XCTAssertEqual(numbered.manager.workspace(for: numberedToken), numbered.workspace3)
        XCTAssertEqual(numbered.manager.windowMode(for: numberedToken), .floating)

        let fixture = try makeFixture()
        let token = addWindow(to: fixture.workspace1, in: fixture, mode: .floating)
        defer { fixture.controller.layoutRefreshController.resetState() }

        XCTAssertTrue(fixture.navigation.moveFocusedWindowToNewWorkspace())

        let created = try XCTUnwrap(fixture.manager.workspaceId(named: "6"))
        XCTAssertEqual(fixture.manager.workspace(for: token), created)
        XCTAssertEqual(fixture.manager.windowMode(for: token), .floating)
        XCTAssertEqual(fixture.manager.activeWorkspace(on: fixture.monitorA.id)?.id, created)
    }

    func testMoveToNewWorkspaceWithoutFocusedWindowCreatesNothing() throws {
        let fixture = try makeFixture()
        let workspaces = fixture.manager.workspaces.map(\.id)
        defer { fixture.controller.layoutRefreshController.resetState() }

        XCTAssertFalse(fixture.navigation.moveFocusedWindowToNewWorkspace())
        XCTAssertEqual(fixture.router.handle(IPCCommandRequest.workspace(.moveToNew)), .notFound)
        XCTAssertEqual(fixture.controller.commandHandler.performCommand(.workspace(.moveToNew)), .executed)

        XCTAssertEqual(fixture.manager.workspaces.map(\.id), workspaces)
        XCTAssertEqual(fixture.manager.activeWorkspace(on: fixture.monitorA.id)?.id, fixture.workspace1)
    }

    func testMoveToNewWorkspaceRoutesThroughIPCAndHotkey() throws {
        let fixture = try makeFixture()
        let manager = fixture.manager
        let token = addWindow(to: fixture.workspace1, in: fixture)
        defer { fixture.controller.layoutRefreshController.resetState() }

        XCTAssertEqual(fixture.router.handle(IPCCommandRequest.workspace(.moveToNew)), .executed)
        let first = try XCTUnwrap(manager.workspaceId(named: "6"))
        XCTAssertEqual(manager.workspace(for: token), first)

        XCTAssertEqual(fixture.controller.commandHandler.performCommand(.workspace(.moveToNew)), .executed)
        let second = try XCTUnwrap(manager.workspaceId(named: "7"))
        XCTAssertEqual(manager.workspace(for: token), second)
        XCTAssertEqual(manager.activeWorkspace(on: fixture.monitorA.id)?.id, second)
    }

    func testSwitchToNewWorkspaceCreatesEmptyWorkspaceOnInteractionMonitorUntilCollected() throws {
        let fixture = try makeFixture()
        let manager = fixture.manager
        let configurations = fixture.controller.settings.workspaces.configurations
        _ = manager.setInteractionMonitor(fixture.monitorB.id)
        defer { fixture.controller.layoutRefreshController.resetState() }

        XCTAssertTrue(fixture.navigation.switchToNewWorkspace())

        let created = try XCTUnwrap(manager.workspaceId(named: "4"))
        XCTAssertEqual(manager.monitorId(for: created), fixture.monitorB.id)
        XCTAssertEqual(manager.activeWorkspace(on: fixture.monitorB.id)?.id, created)
        XCTAssertEqual(manager.activeWorkspace(on: fixture.monitorA.id)?.id, fixture.workspace1)
        XCTAssertEqual(fixture.controller.activeWorkspace()?.id, created)
        XCTAssertTrue(manager.entries(in: created).isEmpty)
        XCTAssertEqual(fixture.controller.settings.workspaces.configurations, configurations)

        manager.garbageCollectUnusedWorkspaces(focusedWorkspaceId: created)
        XCTAssertNotNil(manager.descriptor(for: created))

        XCTAssertTrue(manager.setActiveWorkspace(fixture.workspace2, on: fixture.monitorB.id))
        manager.garbageCollectUnusedWorkspaces(focusedWorkspaceId: fixture.workspace2)
        XCTAssertNil(manager.descriptor(for: created))
    }

    func testSwitchToNewWorkspaceRoutesThroughIPCAndHotkey() throws {
        let fixture = try makeFixture()
        let manager = fixture.manager
        defer { fixture.controller.layoutRefreshController.resetState() }

        XCTAssertEqual(fixture.router.handle(IPCCommandRequest.workspace(.switchToNew)), .executed)
        let first = try XCTUnwrap(manager.workspaceId(named: "6"))
        XCTAssertEqual(manager.activeWorkspace(on: fixture.monitorA.id)?.id, first)

        XCTAssertEqual(fixture.controller.commandHandler.performCommand(.workspace(.switchToNew)), .executed)
        let second = try XCTUnwrap(manager.workspaceId(named: "7"))
        XCTAssertEqual(manager.monitorId(for: second), fixture.monitorA.id)
        XCTAssertEqual(manager.activeWorkspace(on: fixture.monitorA.id)?.id, second)
    }

    func testMoveNextAndPreviousTargetTheWorkspacesSwitchNextAndPreviousShow() throws {
        let expectations: [(start: Int, isNext: Bool, hidesEmpty: Bool, target: Int)] = [
            (1, true, false, 3),
            (3, true, false, 5),
            (5, true, false, 1),
            (1, false, false, 5),
            (3, false, false, 1),
            (5, false, false, 3),
            (1, true, true, 5),
            (5, true, true, 1),
            (1, false, true, 5),
            (5, false, true, 1)
        ]

        for entry in expectations {
            let label = "start \(entry.start) next \(entry.isNext) hides empty \(entry.hidesEmpty)"
            let switched = try makeCycleFixture(start: entry.start, hidesEmpty: entry.hidesEmpty)
            switched.fixture.navigation.switchWorkspaceRelative(isNext: entry.isNext)
            let switchTarget = switched.fixture.manager.activeWorkspace(on: switched.fixture.monitorA.id)?.name
            switched.fixture.controller.layoutRefreshController.resetState()

            let moved = try makeCycleFixture(start: entry.start, hidesEmpty: entry.hidesEmpty)
            XCTAssertTrue(moved.fixture.navigation.moveFocusedWindowRelative(isNext: entry.isNext), label)
            let moveTarget = moved.fixture.manager.workspace(for: moved.window)
                .flatMap { moved.fixture.manager.descriptor(for: $0)?.name }
            moved.fixture.controller.layoutRefreshController.resetState()

            XCTAssertEqual(moveTarget, switchTarget, label)
            XCTAssertEqual(moveTarget, String(entry.target), label)
        }
    }

    func testRelativeMovesRouteThroughIPCAndHotkeyAndReportMissingTargets() throws {
        let fixture = try makeFixture()
        let manager = fixture.manager
        defer { fixture.controller.layoutRefreshController.resetState() }

        XCTAssertEqual(fixture.router.handle(IPCCommandRequest.workspace(.moveNext)), .notFound)
        XCTAssertEqual(fixture.router.handle(IPCCommandRequest.workspace(.movePrevious)), .notFound)

        let token = addWindow(to: fixture.workspace1, in: fixture)
        XCTAssertEqual(fixture.router.handle(IPCCommandRequest.workspace(.moveNext)), .executed)
        XCTAssertEqual(manager.workspace(for: token), fixture.workspace3)
        XCTAssertEqual(manager.activeWorkspace(on: fixture.monitorA.id)?.id, fixture.workspace1)

        let second = addWindow(to: fixture.workspace1, in: fixture, windowId: 12)
        XCTAssertEqual(fixture.router.handle(IPCCommandRequest.workspace(.movePrevious)), .executed)
        XCTAssertEqual(manager.workspace(for: second), fixture.workspace5)

        let third = addWindow(to: fixture.workspace1, in: fixture, windowId: 13)
        XCTAssertEqual(fixture.controller.commandHandler.performCommand(.workspace(.moveNext)), .executed)
        XCTAssertEqual(manager.workspace(for: third), fixture.workspace3)
        let fourth = addWindow(to: fixture.workspace1, in: fixture, windowId: 14)
        XCTAssertEqual(fixture.controller.commandHandler.performCommand(.workspace(.movePrevious)), .executed)
        XCTAssertEqual(manager.workspace(for: fourth), fixture.workspace5)

        let lone = addWindow(to: fixture.workspace2, in: fixture, windowId: 15)
        _ = manager.setInteractionMonitor(fixture.monitorB.id)
        XCTAssertFalse(fixture.navigation.moveFocusedWindowRelative(isNext: true))
        XCTAssertEqual(fixture.router.handle(IPCCommandRequest.workspace(.moveNext)), .noChange)
        XCTAssertEqual(manager.workspace(for: lone), fixture.workspace2)
    }

    private struct CycleFixture {
        let fixture: Fixture
        let window: WindowToken
    }

    private func makeCycleFixture(start: Int, hidesEmpty: Bool) throws -> CycleFixture {
        let fixture = try makeFixture()
        let manager = fixture.manager
        fixture.controller.settings.workspaceBar.hideEmptyWorkspaces = hidesEmpty
        let startWorkspace = try XCTUnwrap(manager.workspaceId(named: String(start)))
        let occupied = try XCTUnwrap(manager.workspaceId(named: start == 5 ? "1" : "5"))
        _ = addWindow(to: occupied, in: fixture, pid: 474_002, windowId: 21, focus: false)
        XCTAssertTrue(manager.setActiveWorkspace(startWorkspace, on: fixture.monitorA.id))
        let window = addWindow(to: startWorkspace, in: fixture)
        fixture.controller.layoutRefreshController.resetState()
        return CycleFixture(fixture: fixture, window: window)
    }

    private func runPendingPostLayoutActions(in fixture: Fixture) throws {
        let actions = try XCTUnwrap(
            fixture.controller.layoutRefreshController.layoutState.pendingRefresh?.postLayoutActions
        )
        XCTAssertEqual(actions.count, 1)
        for action in actions {
            XCTAssertTrue(action.isCurrent(using: fixture.manager))
            action.runIfCurrent(using: fixture.manager)
        }
    }

    private func addWindow(
        to workspaceId: WorkspaceDescriptor.ID,
        in fixture: Fixture,
        pid: pid_t = 474_001,
        windowId: Int = 11,
        mode: TrackedWindowMode = .tiling,
        focus: Bool = true
    ) -> WindowToken {
        let token = fixture.manager.addWindow(
            AXWindowRef(element: AXUIElementCreateApplication(pid), windowId: windowId),
            pid: pid,
            windowId: windowId,
            to: workspaceId,
            mode: mode
        )
        if mode == .tiling {
            fixture.manager.withEngineMutationScope(in: workspaceId) {
                _ = fixture.controller.niriEngine?.addWindow(token: token, to: workspaceId, afterSelection: nil)
            }
        }
        if focus {
            XCTAssertTrue(fixture.manager.setManagedFocus(token, in: workspaceId))
            XCTAssertEqual(fixture.manager.selectedManagedToken, token)
        }
        return token
    }

    private func makeFixture() throws -> Fixture {
        let monitorA = makeMonitor(displayId: 474_100, name: "A", frame: CGRect(x: 0, y: 0, width: 1000, height: 800))
        let monitorB = makeMonitor(
            displayId: 474_101,
            name: "B",
            frame: CGRect(x: 1000, y: 0, width: 1000, height: 800)
        )
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "OmniWMWorkspaceRelativeNavigationTests-\(UUID().uuidString)",
            isDirectory: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let settings = SettingsStore(
            persistence: SettingsFilePersistence(
                directory: root.appendingPathComponent("config", isDirectory: true),
                startWatching: false,
                deferSaves: false
            ),
            runtimeState: RuntimeStateStore(
                directory: root.appendingPathComponent("state", isDirectory: true),
                deferSaves: false
            ),
            autosaveEnabled: false
        )
        settings.animationsEnabled = false
        settings.focus.followsWindowToMonitor = false
        settings.workspaces.configurations = [("1", monitorA), ("2", monitorB), ("3", monitorA), ("5", monitorA)]
            .map { name, monitor in
                WorkspaceConfiguration(
                    name: name,
                    monitorAssignment: .specificDisplay(OutputId(from: monitor)),
                    layoutType: .niri
                )
            }
        let focusRecorder = FocusRecorder()
        let controller = WMController(
            settings: settings,
            windowFocusOperations: WindowFocusOperations(
                activateApp: { _ in },
                focusSpecificWindow: { _, windowId, _ in focusRecorder.focusedWindowIds.append(windowId) },
                raiseWindow: { _ in }
            )
        )
        let niriEngine = NiriLayoutEngine()
        niriEngine.animationClock = controller.animationClock
        controller.niriEngine = niriEngine
        let manager = controller.workspaceManager
        manager.applyMonitorConfigurationChange([monitorA, monitorB])
        manager.applySettings()
        controller.syncMonitorsToNiriEngine()
        let workspace1 = try XCTUnwrap(manager.workspaceId(named: "1"))
        let workspace2 = try XCTUnwrap(manager.workspaceId(named: "2"))
        XCTAssertTrue(manager.setActiveWorkspace(workspace1, on: monitorA.id, updateInteractionMonitor: false))
        XCTAssertTrue(manager.setActiveWorkspace(workspace2, on: monitorB.id, updateInteractionMonitor: false))
        _ = manager.setInteractionMonitor(monitorA.id)
        controller.layoutRefreshController.resetState()

        return try Fixture(
            controller: controller,
            router: IPCCommandRouter(controller: controller, sessionToken: "test"),
            focusRecorder: focusRecorder,
            monitorA: monitorA,
            monitorB: monitorB,
            workspace1: workspace1,
            workspace2: workspace2,
            workspace3: XCTUnwrap(manager.workspaceId(named: "3")),
            workspace5: XCTUnwrap(manager.workspaceId(named: "5"))
        )
    }

    private func makeMonitor(displayId: CGDirectDisplayID, name: String, frame: CGRect) -> Monitor {
        Monitor(
            id: .init(displayId: displayId),
            displayId: displayId,
            frame: frame,
            visibleFrame: frame,
            hasNotch: false,
            name: name
        )
    }
}
