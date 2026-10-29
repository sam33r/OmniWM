// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import CoreGraphics
import Foundation
@testable import OmniWM
import XCTest

@MainActor
final class FocusFollowsMouseScrollLimitTests: XCTestCase {
    private struct EngineFixture {
        let engine: NiriLayoutEngine
        let workspaceId: WorkspaceDescriptor.ID
        let frame: CGRect
        let orientation: Monitor.Orientation
        let gap: CGFloat
        let windows: [NiriWindow]
        var state: ViewportState

        var context: NiriInteractionContext {
            .init(workspaceId: workspaceId, motion: .disabled, workingFrame: frame, gaps: gap, orientation: orientation)
        }

        func revealDistance(to index: Int) -> CGFloat {
            engine.selectionRevealDistance(node: windows[index], context: context, state: state)
        }

        func viewStart(of state: ViewportState) -> CGFloat {
            state.containerPosition(
                at: state.activeColumnIndex,
                containers: engine.columns(in: workspaceId),
                gap: gap,
                sizeKeyPath: orientation.settledSpanKeyPath
            ) + state.viewOffset
        }

        func layout(of state: ViewportState) -> LayoutResult {
            engine.calculateLayoutWithVisibility(
                state: state,
                workspaceId: workspaceId,
                monitorFrame: frame,
                gaps: (gap, gap),
                orientation: orientation,
                excludedTokens: engine.projectionExclusions(in: workspaceId)
            )
        }

        func primaryOrigin(of rect: CGRect) -> CGFloat {
            orientation == .horizontal ? rect.minX : rect.minY
        }
    }

    @MainActor private struct ControllerFixture {
        let controller: WMController
        let monitor: Monitor
        let workspaceId: WorkspaceDescriptor.ID
        let windows: [NiriWindow]

        var state: ViewportState {
            controller.workspaceManager.niriViewportState(for: workspaceId)
        }

        func hover(_ index: Int) {
            controller.mouseEventHandler.dispatchMouseMoved(
                at: CGPoint(x: monitor.frame.midX, y: monitor.frame.midY),
                windowIdUnderPointer: windows[index].token.windowId
            )
        }

        func viewStart(_ state: ViewportState) -> CGFloat {
            guard let engine = controller.niriEngine else { return state.viewOffset }
            return state.containerPosition(
                at: state.activeColumnIndex,
                containers: engine.columns(in: workspaceId),
                gap: controller.innerGap(for: monitor),
                sizeKeyPath: \.cachedWidth
            ) + state.viewOffset
        }
    }

    // Five one-third columns, scrolled so column 1 overhangs the leading edge, columns 2 and 3
    // are fully visible, and column 4 overhangs the trailing edge.
    private func makeEngineFixture(
        orientation: Monitor.Orientation = .horizontal,
        center: CenterFocusedColumn = .never
    ) -> EngineFixture {
        let engine = NiriLayoutEngine()
        engine.updateConfiguration(centerFocusedColumn: center)
        let workspaceId = WorkspaceDescriptor.ID()
        let frame = CGRect(x: 0, y: 0, width: 1_500, height: 1_500)
        let monitor = Monitor(
            id: Monitor.ID(displayId: 92), displayId: 92, frame: frame, visibleFrame: frame,
            hasNotch: false, name: "Mouse focus scroll"
        )
        engine.syncWorkspaceAssignments(
            [(workspaceId: workspaceId, monitor: monitor)],
            orientations: [monitor.id: orientation]
        )
        let windows = (1 ... 5).map {
            engine.addWindow(token: WindowToken(pid: 914, windowId: $0), to: workspaceId, afterSelection: nil)
        }
        for column in engine.columns(in: workspaceId) {
            column.width = .proportion(1.0 / 3.0)
            column.height = .proportion(1.0 / 3.0)
        }
        let gap: CGFloat = 12
        engine.resolvePrimaryContainerSpans(in: workspaceId, workingFrame: frame, gaps: gap, orientation: orientation)
        var state = ViewportState(selectedNodeId: windows[2].id)
        state.activeColumnIndex = 2
        state.jumpOffset(to: -gap - 200)
        return EngineFixture(
            engine: engine, workspaceId: workspaceId, frame: frame, orientation: orientation, gap: gap,
            windows: windows, state: state
        )
    }

    func testRevealDistanceIsZeroForFullyVisibleColumnsAndMeasuresOverhang() {
        for orientation in [Monitor.Orientation.horizontal, .vertical] {
            let fixture = makeEngineFixture(orientation: orientation)

            XCTAssertEqual(fixture.revealDistance(to: 2), 0, "\(orientation)")
            XCTAssertEqual(fixture.revealDistance(to: 3), 0, "\(orientation)")
            XCTAssertEqual(fixture.revealDistance(to: 1), 296, accuracy: 0.01, "\(orientation)")
            XCTAssertEqual(fixture.revealDistance(to: 4), 200, accuracy: 0.01, "\(orientation)")
        }
    }

    func testRevealDistanceMatchesTheScrollActivationPerforms() {
        for orientation in [Monitor.Orientation.horizontal, .vertical] {
            for center in [CenterFocusedColumn.never, .always, .onOverflow] {
                let fixture = makeEngineFixture(orientation: orientation, center: center)
                for index in fixture.windows.indices {
                    let label = "\(orientation) \(center) column \(index)"
                    let distance = fixture.revealDistance(to: index)
                    var activated = fixture.state
                    fixture.engine.ensureSelectionVisible(
                        node: fixture.windows[index],
                        context: fixture.context,
                        state: &activated
                    )

                    let scrolled = abs(fixture.viewStart(of: activated) - fixture.viewStart(of: fixture.state))
                    XCTAssertEqual(distance, scrolled, accuracy: 0.01, label)
                }
            }
        }
    }

    func testRevealDistanceUsesTheProjectedColumnsWhenWindowsAreExcluded() {
        for center in [CenterFocusedColumn.never, .always] {
            let fixture = makeEngineFixture(center: center)
            fixture.engine.setProjectionExclusions([fixture.windows[3].token], in: fixture.workspaceId)
            let before = fixture.layout(of: fixture.state)
            for index in [1, 2, 4] {
                let label = "\(center) column \(index)"
                let token = fixture.windows[index].token
                let distance = fixture.revealDistance(to: index)
                var activated = fixture.state
                fixture.engine.ensureSelectionVisible(
                    node: fixture.windows[index],
                    context: fixture.context,
                    state: &activated
                )
                let after = fixture.layout(of: activated)

                guard let beforeFrame = before.frames[token], let afterFrame = after.frames[token] else {
                    XCTFail("Missing frame for \(label)")
                    continue
                }
                let scrolled = abs(fixture.primaryOrigin(of: afterFrame) - fixture.primaryOrigin(of: beforeFrame))
                XCTAssertEqual(distance, scrolled, accuracy: 0.01, label)
            }
        }
    }

    func testRevealDistanceLeavesColumnSpansUntouched() {
        let fixture = makeEngineFixture(center: .always)
        fixture.engine.setProjectionExclusions([fixture.windows[0].token], in: fixture.workspaceId)
        let spans = fixture.engine.columns(in: fixture.workspaceId).map(\.cachedWidth)

        XCTAssertGreaterThan(fixture.revealDistance(to: 4), 0)

        XCTAssertEqual(fixture.engine.columns(in: fixture.workspaceId).map(\.cachedWidth), spans)
    }

    func testFocusSettingsClampThePercentageAndAllowUnlimited() {
        let focus = FocusSettings()
        XCTAssertNil(focus.followsMouseMaxScrollPercent)
        var changes = 0
        focus.onChange = { changes += 1 }

        for (value, expected) in [(0, 0), (35, 35), (100, 100), (-10, 0), (150, 100)] {
            changes = 0
            focus.followsMouseMaxScrollPercent = value
            XCTAssertEqual(focus.followsMouseMaxScrollPercent, expected)
            XCTAssertEqual(changes, 1)
        }
        changes = 0
        focus.followsMouseMaxScrollPercent = nil
        XCTAssertNil(focus.followsMouseMaxScrollPercent)
        XCTAssertEqual(changes, 1)

        var imported = SettingsExport.defaults().focus
        imported.followsMouseMaxScrollPercent = 400
        focus.apply(imported)
        XCTAssertEqual(focus.export().followsMouseMaxScrollPercent, 100)
    }

    func testHoverFocusesFullyVisibleColumnAtZeroPercent() throws {
        try withControllerFixture(maxScrollPercent: 0) { fixture in
            fixture.hover(1)

            XCTAssertEqual(fixture.state.selectedNodeId, fixture.windows[1].id)
            XCTAssertEqual(fixture.state.activeColumnIndex, 1)
        }
    }

    func testHoverSkipsPartiallyVisibleColumnBeyondTheLimit() throws {
        try withControllerFixture(maxScrollPercent: 0) { fixture in
            let initial = fixture.state

            fixture.hover(2)

            XCTAssertEqual(fixture.state.selectedNodeId, fixture.windows[0].id)
            XCTAssertEqual(fixture.state.activeColumnIndex, initial.activeColumnIndex)
            XCTAssertEqual(fixture.state.viewOffset, initial.viewOffset)
            XCTAssertNil(fixture.controller.intentLedger.activeManagedRequest)
        }
    }

    func testHoverFocusesPartiallyVisibleColumnWithinTheLimit() throws {
        try withControllerFixture(maxScrollPercent: 100) { fixture in
            fixture.hover(2)

            XCTAssertEqual(fixture.state.selectedNodeId, fixture.windows[2].id)
            XCTAssertEqual(fixture.state.activeColumnIndex, 2)
        }
    }

    func testUnlimitedDefaultStillScrollsToHoveredColumn() throws {
        try withControllerFixture(maxScrollPercent: nil) { fixture in
            let initial = fixture.state

            fixture.hover(2)

            XCTAssertEqual(fixture.state.selectedNodeId, fixture.windows[2].id)
            XCTAssertEqual(fixture.state.activeColumnIndex, 2)
            XCTAssertNotEqual(fixture.viewStart(fixture.state), fixture.viewStart(initial))
        }
    }

    private func withControllerFixture(
        maxScrollPercent: Int?,
        _ body: (ControllerFixture) throws -> Void
    ) throws {
        let controller = WindowAdmissionTestSupport.controller(prefix: "FocusFollowsMouseScrollLimitTests")
        defer { controller.layoutRefreshController.resetState() }
        controller.settings.niri.centerFocusedColumn = .never
        controller.settings.focus.followsMouseMaxScrollPercent = maxScrollPercent
        controller.motionPolicy.animationsEnabled = false
        let displayId = CGDirectDisplayID(987_400)
        let frame = CGRect(x: 0, y: 0, width: 1_600, height: 900)
        let monitor = Monitor(
            id: .init(displayId: displayId),
            displayId: displayId,
            frame: frame,
            visibleFrame: frame,
            hasNotch: false,
            name: "Mouse Focus Scroll"
        )
        controller.settings.workspaces.configurations = [
            WorkspaceConfiguration(
                name: "1",
                monitorAssignment: .specificDisplay(OutputId(from: monitor)),
                layoutType: .niri
            )
        ]
        let manager = controller.workspaceManager
        manager.applyMonitorConfigurationChange([monitor])
        manager.applySettings()
        let workspaceId = try XCTUnwrap(manager.workspaceId(for: "1", createIfMissing: true))
        manager.assignWorkspaceToMonitor(workspaceId, monitorId: monitor.id)
        _ = manager.setActiveWorkspace(workspaceId, on: monitor.id)
        _ = manager.focusWorkspace(id: workspaceId)
        controller.niriLayoutHandler.enableNiriLayout()
        let engine = try XCTUnwrap(controller.niriEngine)
        var windows: [NiriWindow] = []
        for index in 0 ..< 3 {
            let token = WindowToken(pid: pid_t(987_500 + index), windowId: 987_600 + index)
            _ = WindowAdmissionTestSupport.track(token, in: workspaceId, controller: controller)
            windows.append(engine.addWindow(token: token, to: workspaceId, afterSelection: windows.last?.id))
        }
        for column in engine.columns(in: workspaceId) {
            column.width = .fixed(600)
            column.cachedWidth = 600
            column.height = .fixed(600)
            column.cachedHeight = 600
        }
        manager.updateNiriViewportState(
            ViewportState(
                activeColumnIndex: 0,
                viewOffset: -controller.innerGap(for: monitor),
                selectedNodeId: windows[0].id
            ),
            for: workspaceId
        )
        controller.layoutRefreshController.resetState()
        let blocker = Task { @MainActor in }
        controller.layoutRefreshController.layoutState.activeRefreshTask = blocker
        controller.layoutRefreshController.layoutState.activeRefresh = .init(
            kind: .immediateRelayout,
            reason: .layoutCommand,
            affectedWorkspaceIds: [workspaceId]
        )
        controller.setFocusFollowsMouse(true)
        try body(ControllerFixture(
            controller: controller,
            monitor: monitor,
            workspaceId: workspaceId,
            windows: windows
        ))
    }
}
