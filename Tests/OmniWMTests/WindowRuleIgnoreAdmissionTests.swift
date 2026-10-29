// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import ApplicationServices
import CoreGraphics
@testable import OmniWM
import XCTest

@MainActor
final class WindowRuleIgnoreAdmissionTests: XCTestCase {
    private static let launcherTitle = "Goose Launcher"
    private static let launcherFrame = CGRect(x: 200, y: 200, width: 640, height: 120)

    private let ignoreRule = AppRule(
        bundleId: "",
        titleSubstring: WindowRuleIgnoreAdmissionTests.launcherTitle,
        layout: .ignore
    )

    func testIgnoreRulePreventsCreateAdmission() throws {
        let controller = WindowAdmissionTestSupport.controller(prefix: "WindowRuleIgnoreAdmissionTests")
        defer {
            controller.layoutRefreshController.resetState()
            controller.axManager.cleanup()
        }
        let workspaceId = try XCTUnwrap(controller.workspaceManager.workspaceId(for: "1", createIfMissing: true))
        _ = controller.workspaceManager.focusWorkspace(id: workspaceId)
        let token = WindowToken(pid: 467_301, windowId: 467_302)
        injectLauncherFacts(for: [token], into: controller)

        guard case let .prepared(candidate) = prepareCreate(token, controller: controller) else {
            return XCTFail("The launcher should be admitted while no rule ignores it")
        }
        XCTAssertEqual(candidate.mode, .floating)

        controller.windowRuleEngine.rebuild(rules: [ignoreRule])

        guard case let .ignored(ignoredToken, reason) = prepareCreate(token, controller: controller) else {
            return XCTFail("An ignore rule should reject the launcher before admission")
        }
        XCTAssertEqual(ignoredToken, token)
        XCTAssertEqual(reason, .ignoredByRule)
        XCTAssertNil(controller.workspaceManager.entry(for: token))
    }

    func testRuleChangedToIgnoreReleasesManagedWindows() async throws {
        let controller = WindowAdmissionTestSupport.controller(prefix: "WindowRuleIgnoreAdmissionTests")
        defer {
            controller.layoutRefreshController.resetState()
            controller.axManager.cleanup()
        }
        let manager = controller.workspaceManager
        let workspaceId = try XCTUnwrap(manager.workspaceId(for: "1", createIfMissing: true))
        _ = manager.focusWorkspace(id: workspaceId)
        controller.motionPolicy.animationsEnabled = false
        controller.niriLayoutHandler.enableNiriLayout()
        await WindowAdmissionTestSupport.drainLayoutRefreshes(controller)
        controller.layoutRefreshController.layoutState.hasCompletedInitialRefresh = true
        controller.axEventHandler.windowInfoBatchProvider = { _ in [:] }

        let tiled = WindowToken(pid: 467_311, windowId: 467_312)
        let floating = WindowToken(pid: 467_311, windowId: 467_313)
        let sibling = WindowToken(pid: 467_314, windowId: 467_315)
        _ = WindowAdmissionTestSupport.track(tiled, in: workspaceId, controller: controller)
        _ = WindowAdmissionTestSupport.track(sibling, in: workspaceId, controller: controller)
        _ = manager.addWindow(
            WindowAdmissionTestSupport.axRef(for: floating),
            pid: floating.pid,
            windowId: floating.windowId,
            to: workspaceId,
            mode: .floating
        )
        controller.layoutRefreshController.requestRelayout(
            reason: .axWindowCreated,
            affectedWorkspaceIds: [workspaceId]
        )
        await WindowAdmissionTestSupport.drainLayoutRefreshes(controller)
        let engine = try XCTUnwrap(controller.niriEngine)
        XCTAssertNotNil(engine.findNode(for: tiled, in: workspaceId))
        injectLauncherFacts(for: [tiled, floating], into: controller)

        controller.windowRuleEngine.rebuild(rules: [ignoreRule])
        let outcome = await controller.reevaluateWindowRules(for: [.window(tiled), .window(floating)])

        XCTAssertTrue(outcome.evaluatedAnyWindow)
        XCTAssertTrue(outcome.relayoutNeeded)
        XCTAssertNil(manager.entry(for: tiled))
        XCTAssertNil(manager.entry(for: floating))
        XCTAssertNotNil(manager.entry(for: sibling))

        await WindowAdmissionTestSupport.drainLayoutRefreshes(controller)

        XCTAssertNil(engine.findNode(for: tiled, in: workspaceId))
        XCTAssertNotNil(engine.findNode(for: sibling, in: workspaceId))
        XCTAssertFalse(manager.allEntries().contains { $0.token == tiled || $0.token == floating })
    }

    private func prepareCreate(
        _ token: WindowToken,
        controller: WMController
    ) -> AXEventHandler.CreatePreparationOutcome {
        controller.axEventHandler.prepareCreateCandidate(
            windowId: UInt32(token.windowId),
            windowInfo: Self.launcherWindowInfo(for: token),
            fallbackToken: token,
            fallbackAXRef: WindowAdmissionTestSupport.axRef(for: token)
        )
    }

    private static func launcherWindowInfo(for token: WindowToken) -> WindowServerInfo {
        WindowServerInfo(id: UInt32(token.windowId), pid: token.pid, level: 3, frame: Self.launcherFrame)
    }

    private func injectLauncherFacts(for tokens: Set<WindowToken>, into controller: WMController) {
        controller.windowDispositionEvaluationForTests = { [weak controller] candidate in
            guard tokens.contains(candidate) else { return nil }
            return controller?.evaluateWindowDisposition(
                token: candidate,
                evidence: AXWindowDecisionEvidence(
                    facts: AXWindowFacts(
                        role: kAXWindowRole as String,
                        subrole: kAXStandardWindowSubrole as String,
                        title: Self.launcherTitle,
                        hasCloseButton: true,
                        hasFullscreenButton: false,
                        fullscreenButtonEnabled: false,
                        hasZoomButton: false,
                        hasMinimizeButton: false,
                        appPolicy: .accessory,
                        bundleId: nil,
                        attributeFetchSucceeded: true
                    ),
                    sizeConstraints: .unconstrained
                ),
                appFullscreen: false,
                windowInfo: Self.launcherWindowInfo(for: candidate),
                admissionGeometry: WindowAdmissionGeometryEvidence(
                    isSizeSettable: true,
                    frame: Self.launcherFrame
                )
            )
        }
    }
}
