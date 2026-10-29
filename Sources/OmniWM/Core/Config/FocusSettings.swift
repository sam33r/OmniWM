// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import AppKit
import Carbon
import Foundation
import OmniWMIPC

@MainActor @Observable
final class FocusSettings {
    private nonisolated static let defaults = SettingsExport.Focus.defaults()
    @ObservationIgnored var onChange: (() -> Void)?

    nonisolated static let edgeNavigationIntervalRange = 0.25 ... 2.0
    nonisolated static let edgeNavigationIntervalStep = 0.25

    nonisolated static func normalizedEdgeNavigationInterval(_ value: Double) -> Double {
        guard value.isFinite else { return defaults.edgeNavigationInterval }
        let clamped = min(max(value, edgeNavigationIntervalRange.lowerBound), edgeNavigationIntervalRange.upperBound)
        return (clamped / edgeNavigationIntervalStep).rounded() * edgeNavigationIntervalStep
    }

    nonisolated static let followsMouseMaxScrollPercentRange = 0 ... 100

    nonisolated static func normalizedFollowsMouseMaxScrollPercent(_ value: Int?) -> Int? {
        value.map {
            min(max($0, followsMouseMaxScrollPercentRange.lowerBound), followsMouseMaxScrollPercentRange.upperBound)
        }
    }

    var followsMouse = FocusSettings.defaults.followsMouse {
        didSet { onChange?() }
    }

    var followsMouseMaxScrollPercent = FocusSettings.defaults.followsMouseMaxScrollPercent {
        didSet {
            let normalized = FocusSettings.normalizedFollowsMouseMaxScrollPercent(followsMouseMaxScrollPercent)
            guard normalized == followsMouseMaxScrollPercent else {
                followsMouseMaxScrollPercent = normalized
                return
            }
            onChange?()
        }
    }

    var edgeNavigationInterval = FocusSettings.defaults.edgeNavigationInterval {
        didSet {
            let normalized = FocusSettings.normalizedEdgeNavigationInterval(edgeNavigationInterval)
            guard normalized == edgeNavigationInterval else {
                edgeNavigationInterval = normalized
                return
            }
            onChange?()
        }
    }

    var raiseOnMouseFocus = FocusSettings.defaults.raiseOnMouseFocus {
        didSet { onChange?() }
    }

    var lockModifier = FocusSettings.defaults.lockModifier {
        didSet { onChange?() }
    }

    var moveMouseToFocusedWindow = FocusSettings.defaults.moveMouseToFocusedWindow {
        didSet { onChange?() }
    }

    var followsWindowToMonitor = FocusSettings.defaults.followsWindowToMonitor {
        didSet { onChange?() }
    }

    var crossesMonitorAtEdge = FocusSettings.defaults.crossesMonitorAtEdge {
        didSet { onChange?() }
    }

    var moveCrossesMonitorAtEdge = FocusSettings.defaults.moveCrossesMonitorAtEdge {
        didSet { onChange?() }
    }

    var moveToMonitorWrapsAround = FocusSettings.defaults.moveToMonitorWrapsAround {
        didSet { onChange?() }
    }

    var relativeWorkspaceEdgeBehavior = FocusSettings.defaults.relativeWorkspaceEdgeBehavior {
        didSet { onChange?() }
    }

    func export() -> SettingsExport.Focus {
        SettingsExport.Focus(
            followsMouse: followsMouse,
            edgeNavigationInterval: edgeNavigationInterval,
            raiseOnMouseFocus: raiseOnMouseFocus,
            lockModifier: lockModifier,
            moveMouseToFocusedWindow: moveMouseToFocusedWindow,
            followsWindowToMonitor: followsWindowToMonitor,
            crossesMonitorAtEdge: crossesMonitorAtEdge,
            moveCrossesMonitorAtEdge: moveCrossesMonitorAtEdge,
            moveToMonitorWrapsAround: moveToMonitorWrapsAround,
            relativeWorkspaceEdgeBehavior: relativeWorkspaceEdgeBehavior,
            followsMouseMaxScrollPercent: followsMouseMaxScrollPercent
        )
    }

    func apply(_ focus: SettingsExport.Focus) {
        followsMouse = focus.followsMouse
        edgeNavigationInterval = focus.edgeNavigationInterval
        raiseOnMouseFocus = focus.raiseOnMouseFocus
        lockModifier = focus.lockModifier
        moveMouseToFocusedWindow = focus.moveMouseToFocusedWindow
        followsWindowToMonitor = focus.followsWindowToMonitor
        crossesMonitorAtEdge = focus.crossesMonitorAtEdge
        moveCrossesMonitorAtEdge = focus.moveCrossesMonitorAtEdge
        moveToMonitorWrapsAround = focus.moveToMonitorWrapsAround
        relativeWorkspaceEdgeBehavior = focus.relativeWorkspaceEdgeBehavior
        followsMouseMaxScrollPercent = focus.followsMouseMaxScrollPercent
    }
}
