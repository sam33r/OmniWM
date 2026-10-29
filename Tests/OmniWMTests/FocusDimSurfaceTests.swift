// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import AppKit
@testable import OmniWM
import OmniWMIPC
import XCTest

@MainActor
final class FocusDimSurfaceTests: XCTestCase {
    /// Tracks visibility instead of putting a real dark panel on screen during tests.
    private final class QuietDimPanel: FocusDimPanel {
        var shown = false

        override var isVisible: Bool {
            shown
        }

        override func orderFront(_: Any?) {
            shown = true
        }

        override func orderOut(_: Any?) {
            shown = false
        }
    }

    @MainActor
    private final class Recorder {
        var panels: [QuietDimPanel] = []
        var screencaptureExclusions = 0

        func operations(hideDelay: Duration = .zero) -> FocusDimApplier.Operations {
            FocusDimApplier.Operations(
                createPanel: { [unowned self] frame in
                    _ = NSApplication.shared
                    let panel = QuietDimPanel(frame: frame)
                    panels.append(panel)
                    return panel
                },
                excludeFromScreencaptureSelection: { [unowned self] _ in screencaptureExclusions += 1 },
                hideDelay: hideDelay
            )
        }

        var shownPanels: [QuietDimPanel] {
            panels.filter(\.shown)
        }
    }

    private let frameA = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    private let frameB = CGRect(x: 1600, y: 0, width: 1200, height: 800)
    private let windowFrame = CGRect(x: 100, y: 100, width: 600, height: 400)

    func testApplierCoversEachDisplayAboveNormalWindowsWithAHoleForTheFocusedWindow() throws {
        let recorder = Recorder()
        let coordinator = SurfaceCoordinator(scene: SurfaceScene())
        let applier = FocusDimApplier(operations: recorder.operations(), surfaceCoordinator: coordinator)
        let token = WindowToken(pid: 1, windowId: 500)
        defer { applier.cleanup() }

        applier.apply(dim(token, [(frameA, windowFrame), (frameB, nil)], 0.6))

        XCTAssertEqual(recorder.panels.count, 2)
        XCTAssertEqual(recorder.panels.map(\.frame), [frameA, frameB])
        XCTAssertEqual(recorder.panels.map(\.shown), [true, true])
        XCTAssertEqual(recorder.panels.map(\.alphaValue), [0.6, 0.6])
        XCTAssertEqual(recorder.panels.map(\.level), [FocusDimPanel.dimLevel, FocusDimPanel.dimLevel])
        XCTAssertGreaterThan(FocusDimPanel.dimLevel.rawValue, NSWindow.Level.normal.rawValue)
        XCTAssertLessThan(FocusDimPanel.dimLevel.rawValue, NSWindow.Level.floating.rawValue)
        XCTAssertTrue(recorder.panels.allSatisfy(\.ignoresMouseEvents))
        XCTAssertEqual(recorder.panels[0].hole, windowFrame)
        XCTAssertNil(recorder.panels[1].hole)
        XCTAssertEqual(recorder.screencaptureExclusions, 2)
        let ids = applier.panelWindowIds
        XCTAssertEqual(ids.count, 2)
        XCTAssertTrue(ids.allSatisfy { coordinator.isPassthrough(windowNumber: Int($0)) })
        XCTAssertFalse(coordinator.containsInteractive(point: CGPoint(x: 10, y: 10)))

        let moved = windowFrame.offsetBy(dx: 1500, dy: 0)
        applier.apply(dim(token, [(frameA, moved), (frameB, moved)], 0.4))
        XCTAssertEqual(recorder.panels.map(\.hole), [moved, moved])
        XCTAssertEqual(recorder.panels.map(\.alphaValue), [0.4, 0.4])

        applier.apply(dim(token, [(frameA, moved)], 0.4))
        XCTAssertEqual(applier.panelWindowIds, [ids[0]])
        XCTAssertFalse(recorder.panels[1].shown)
        XCTAssertFalse(coordinator.contains(windowNumber: Int(ids[1])))

        applier.apply(nil)
        XCTAssertNil(applier.applied)
        XCTAssertFalse(recorder.panels[0].shown)

        applier.apply(dim(token, [(frameA, moved)], 0.4))
        XCTAssertTrue(recorder.panels[0].shown)

        applier.cleanup()
        XCTAssertTrue(applier.panelWindowIds.isEmpty)
        XCTAssertFalse(coordinator.contains(windowNumber: Int(ids[0])))
    }

    func testLosingTheFocusedWindowBrieflyKeepsTheLayerUpInsteadOfFlashing() async throws {
        let recorder = Recorder()
        let applier = FocusDimApplier(
            operations: recorder.operations(hideDelay: .milliseconds(50)),
            surfaceCoordinator: SurfaceCoordinator(scene: SurfaceScene())
        )
        defer { applier.cleanup() }
        let first = dim(WindowToken(pid: 1, windowId: 500), [(frameA, windowFrame)], 0.6)
        let second = dim(WindowToken(pid: 1, windowId: 600), [(frameA, windowFrame.offsetBy(dx: 700, dy: 0))], 0.6)

        applier.apply(first)
        applier.apply(nil)
        XCTAssertTrue(recorder.panels[0].shown)
        XCTAssertTrue(applier.isHidePending)
        XCTAssertEqual(applier.applied, first)

        applier.apply(second)
        XCTAssertFalse(applier.isHidePending)
        XCTAssertEqual(recorder.panels[0].hole, second.displays[0].hole)

        applier.apply(nil)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(applier.isHidePending)
        XCTAssertFalse(recorder.panels[0].shown)
        XCTAssertNil(applier.applied)
    }

    func testReconcilerCutsTheFocusedWindowAndBorderOutOnlyWhileEnabled() throws {
        for fullScene in [false, true] {
            let (controller, entry) = try reconcileFixture()
            let recorder = Recorder()
            let applier = FocusDimApplier(
                operations: recorder.operations(),
                surfaceCoordinator: SurfaceCoordinator(scene: SurfaceScene())
            )
            let reconciler = SurfaceReconciler(controller: controller, focusDimApplier: applier)
            defer {
                controller.settings.focus.dimUnfocused = false
                controller.hasStartedServices = false
                reconciler.cleanup()
            }
            func reconcile() {
                if fullScene {
                    reconciler.noteWorldChanged()
                } else {
                    reconciler.noteBorderChanged()
                }
                reconciler.reconcileNow()
            }

            reconcile()
            XCTAssertTrue(recorder.panels.isEmpty, "dimming is off by default")

            controller.settings.focus.dimUnfocused = true
            controller.settings.focus.dimUnfocusedOpacity = 0.7
            reconcile()
            let panel = try XCTUnwrap(recorder.shownPanels.first)
            let borderWidth = controller.resolvedBorderConfig().width
            XCTAssertGreaterThan(borderWidth, 0)
            XCTAssertEqual(applier.applied?.token, entry.token)
            XCTAssertEqual(panel.frame, frameA)
            XCTAssertEqual(panel.alphaValue, 0.7, accuracy: 0.001)
            XCTAssertEqual(panel.hole, windowFrame.insetBy(dx: -borderWidth, dy: -borderWidth))
            XCTAssertEqual(
                applier.applied?.holeCornerRadius,
                WindowCornerRadii.systemDefault.topLeft + borderWidth
            )

            controller.settings.borders.enabled = false
            reconcile()
            XCTAssertEqual(panel.hole, windowFrame)

            let moved = windowFrame.offsetBy(dx: 40, dy: 0)
            controller.axManager.confirmFrameWrite(for: entry.token.windowId, frame: moved)
            reconciler.reconcileAnimationTick()
            XCTAssertEqual(panel.hole, moved, "animation ticks move the hole even without borders")

            controller.settings.focus.dimUnfocused = false
            reconcile()
            XCTAssertNil(applier.applied)
            XCTAssertFalse(panel.shown)
        }
    }

    func testDimIsSkippedWithoutAFocusedManagedWindowOrOnFullscreenSpaces() throws {
        let (controller, entry) = try reconcileFixture()
        controller.settings.focus.dimUnfocused = true
        defer {
            controller.settings.focus.dimUnfocused = false
            controller.hasStartedServices = false
        }
        let world = WorldView(controller: controller)
        XCTAssertEqual(SurfaceDerivation.deriveFocusDim(world: world)?.displays.map(\.frame), [frameA])

        controller.workspaceManager.commitSpaceTopology(SpaceTopology(
            displays: [.init(displayIdentifier: "814101", spaceIds: [1, 2], currentSpaceId: 2)],
            activeSpaceId: 2, fullscreenSpaceIds: [2], windowSpace: [:]
        ))
        XCTAssertNil(SurfaceDerivation.deriveFocusDim(world: world))

        controller.workspaceManager.commitSpaceTopology(SpaceTopology(
            displays: [.init(displayIdentifier: "814101", spaceIds: [1], currentSpaceId: 1)],
            activeSpaceId: 1, fullscreenSpaceIds: [], windowSpace: [:]
        ))
        _ = controller.workspaceManager.removeWindow(pid: entry.token.pid, windowId: entry.token.windowId)
        XCTAssertNil(SurfaceDerivation.deriveFocusDim(world: world))
    }

    func testPointerReportsNamingTheDimLayerAreTreatedAsUnknown() throws {
        let controller = WindowAdmissionTestSupport.controller(prefix: "FocusDimPointerTests")
        let recorder = Recorder()
        let applier = FocusDimApplier(operations: recorder.operations(), surfaceCoordinator: .shared)
        defer { applier.cleanup() }
        applier.apply(dim(WindowToken(pid: 1, windowId: 500), [(frameA, windowFrame)], 0.6))
        let panelId = try XCTUnwrap(applier.panelWindowIds.first.map(Int.init))

        XCTAssertNil(controller.mouseEventHandler.pointerWindowIdIgnoringPassthroughSurfaces(panelId))
        XCTAssertEqual(controller.mouseEventHandler.pointerWindowIdIgnoringPassthroughSurfaces(987_654), 987_654)
        XCTAssertNil(controller.mouseEventHandler.pointerWindowIdIgnoringPassthroughSurfaces(nil))
    }

    func testToggleCommandFlipsTheSettingFromIPCAndHotkey() throws {
        let controller = WindowAdmissionTestSupport.controller(prefix: "FocusDimToggleTests")
        let router = IPCCommandRouter(controller: controller, sessionToken: "test")
        XCTAssertFalse(controller.settings.focus.dimUnfocused)

        XCTAssertEqual(router.handle(IPCCommandRequest.presentation(.dimUnfocused)), .executed)
        XCTAssertTrue(controller.settings.focus.dimUnfocused)
        XCTAssertEqual(controller.commandHandler.performCommand(.presentation(.dimUnfocused)), .executed)
        XCTAssertFalse(controller.settings.focus.dimUnfocused)
        XCTAssertEqual(ActionCatalog.allSpecs().last?.id, "toggleDimUnfocused")
    }

    private func dim(
        _ token: WindowToken,
        _ displays: [(frame: CGRect, hole: CGRect?)],
        _ opacity: Double
    ) -> DesiredFocusDimSurface {
        DesiredFocusDimSurface(
            token: token,
            displays: displays.map { .init(frame: $0.frame, hole: $0.hole) },
            holeCornerRadius: 16,
            opacity: opacity
        )
    }

    private func reconcileFixture() throws -> (controller: WMController, entry: WindowState) {
        let controller = WindowAdmissionTestSupport.controller(prefix: "FocusDimSurfaceTests")
        controller.settings.workspaceBar.enabled = false
        controller.settings.borders.enabled = true
        let monitor = Monitor(
            id: .init(displayId: 814_101), displayId: 814_101,
            frame: frameA, visibleFrame: frameA,
            hasNotch: false, name: "Dim"
        )
        controller.workspaceManager.applyMonitorConfigurationChange([monitor])
        let workspaceId = try XCTUnwrap(controller.workspaceManager.workspaceId(for: "1", createIfMissing: true))
        controller.workspaceManager.assignWorkspaceToMonitor(workspaceId, monitorId: monitor.id)
        _ = controller.workspaceManager.setActiveWorkspace(workspaceId, on: monitor.id)
        _ = controller.workspaceManager.focusWorkspace(id: workspaceId)
        controller.workspaceManager.commitSpaceTopology(SpaceTopology(
            displays: [.init(displayIdentifier: String(monitor.displayId), spaceIds: [1], currentSpaceId: 1)],
            activeSpaceId: 1, fullscreenSpaceIds: [], windowSpace: [:]
        ))
        let token = WindowToken(pid: 814_102, windowId: 814_103)
        _ = WindowAdmissionTestSupport.track(token, in: workspaceId, controller: controller)
        controller.axManager.confirmFrameWrite(for: token.windowId, frame: windowFrame)
        XCTAssertTrue(controller.workspaceManager.setManagedFocus(token, in: workspaceId))
        controller.hasStartedServices = true
        return (controller, try XCTUnwrap(controller.workspaceManager.entry(for: token)))
    }
}
