// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

// Fork: `[focus] dimUnfocused` darkens everything except the focused window, on
// every display, like HazeOver. Each display gets a click-through black panel
// one level above normal windows with a hole cut where the focused window (and
// its border) is, so it doesn't matter how other windows are stacked: with
// focus-follows-mouse the focused window is often not the frontmost one, and
// other apps' windows can't be reordered or made translucent without the Dock's
// connection.

import AppKit
import QuartzCore

struct DesiredFocusDimSurface: Equatable {
    struct Display: Equatable {
        /// The display's frame, in AppKit coordinates.
        var frame: CGRect
        /// The focused window's frame plus its border, when it overlaps this display.
        var hole: CGRect?
    }

    var token: WindowToken
    var displays: [Display]
    var holeCornerRadius: CGFloat
    var opacity: Double
    /// Seconds to cross-fade when the bright window changes, and to fade the layer
    /// in and out. Zero while animations are off.
    var fadeDuration: Double = 0
}

extension SurfaceDerivation {
    static let focusDimFadeDuration = 0.22

    /// Follows the border's notion of the focused window, but only while that window
    /// itself has native focus. While a launcher-style window above the dim layer has
    /// focus (goose, Spotlight, Raycast, the command palette), the managed window that
    /// had focus stays bright; with nothing managed to keep bright (an unmanaged app's
    /// normal window, the desktop, the Settings window) nothing is dimmed.
    /// The hole always uses the window's live bounds when available, also during
    /// animations: mixing in requested frames, which apps such as terminals round to
    /// their own size steps, made the hole's edges flicker between the two.
    @MainActor
    static func deriveFocusDim(world: WorldView) -> DesiredFocusDimSurface? {
        let settings = world.focusDimSettings
        guard settings.enabled, world.hasStartedServices,
              let token = focusDimToken(world: world),
              let entry = world.entry(for: token),
              !world.hasPendingNativeFullscreenTransition(for: token),
              !world.hasPendingNativeFullscreenTransition(in: entry.workspaceId),
              !world.hasPendingWindowClose(for: entry),
              world.systemModalFocusToken != token,
              world.suppressedFocusToken != token,
              world.isManagedWindowDisplayable(entry),
              world.isWorkspaceVisible(entry.workspaceId),
              let focusedMonitor = world.monitor(forWorkspace: entry.workspaceId),
              world.spaceTopology.isDisplayShowingFullscreenSpace(on: focusedMonitor) != true,
              var hole = world.borderFrame(for: entry),
              hole.width > 0, hole.height > 0
        else { return nil }
        var radius = WindowCornerRadii.systemDefault.topLeft
        let border = world.borderConfig
        if border.enabled, border.width > 0 {
            hole = hole.insetBy(dx: -border.width, dy: -border.width)
            radius += border.width
        }
        let displays = world.monitors
            .filter { world.spaceTopology.isDisplayShowingFullscreenSpace(on: $0) != true }
            .map { DesiredFocusDimSurface.Display(frame: $0.frame, hole: $0.frame.intersects(hole) ? hole : nil) }
        guard !displays.isEmpty else { return nil }
        let motion = world.motion
        return DesiredFocusDimSurface(
            token: token,
            displays: displays,
            holeCornerRadius: radius,
            opacity: settings.opacity,
            fadeDuration: motion.animationsEnabled ? focusDimFadeDuration / motion.animationSpeed : 0
        )
    }

    @MainActor
    private static func focusDimToken(world: WorldView) -> WindowToken? {
        if let token = world.borderFocusToken, world.nativeManagedFocusToken == token {
            return token
        }
        guard world.focusedSurfaceIsAboveFocusDim else { return nil }
        return world.selectedManagedToken
    }
}

/// Finds the window level of an app's focused window, for windows OmniWM doesn't
/// manage. OmniWM often knows only the app (it activated before its window was
/// resolved), so without a window id it uses the app's frontmost on-screen window,
/// skipping its menu bar items.
@MainActor
enum FocusDimExternalWindowLevel {
    private struct Lookup {
        let pid: pid_t
        let windowId: Int?
        let layer: Int?
        let time: TimeInterval
    }

    /// The focus-dim surface is derived on every animation frame; the level of a
    /// focused window doesn't change that fast.
    private static var cached: Lookup?

    static func layer(pid: pid_t, windowId: Int?) -> Int? {
        let now = ProcessInfo.processInfo.systemUptime
        if let cached, cached.pid == pid, cached.windowId == windowId, now - cached.time < 0.5 {
            return cached.layer
        }
        let layer = lookUpLayer(pid: pid, windowId: windowId)
        cached = Lookup(pid: pid, windowId: windowId, layer: layer, time: now)
        return layer
    }

    private static func lookUpLayer(pid: pid_t, windowId: Int?) -> Int? {
        if let windowId, let id = CGWindowID(exactly: windowId),
           let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]],
           let layer = info.first?[kCGWindowLayer as String] as? Int
        {
            return layer
        }
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }
        let menuBarLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
        for window in windows where window[kCGWindowOwnerPID as String] as? pid_t == pid {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer < menuBarLevel,
                  (window[kCGWindowAlpha as String] as? Double ?? 1) > 0
            else { continue }
            return layer
        }
        return nil
    }
}

@MainActor
final class FocusDimApplier {
    struct Operations {
        var createPanel: @MainActor (CGRect) -> FocusDimPanel
        var excludeFromScreencaptureSelection: @MainActor (UInt32) -> Void
        /// How long the layer stays up after losing its focused window. Focus changes
        /// pass through brief states with no confirmed focused window; hiding at once
        /// flashed every display.
        var hideDelay: Duration

        static let live = Self(
            createPanel: { FocusDimPanel(frame: $0) },
            excludeFromScreencaptureSelection: { SkyLight.shared.excludeFromScreencaptureWindowSelection($0) },
            hideDelay: .milliseconds(200)
        )
    }

    private static let surfaceIDPrefix = "focus-dim-"
    private let operations: Operations
    private let surfaceCoordinator: SurfaceCoordinator
    private var panels: [FocusDimPanel] = []
    private(set) var applied: DesiredFocusDimSurface?
    private var pendingHide: Task<Void, Never>?

    init(operations: Operations = .live, surfaceCoordinator: SurfaceCoordinator = .shared) {
        self.operations = operations
        self.surfaceCoordinator = surfaceCoordinator
    }

    var panelWindowIds: [UInt32] {
        panels.compactMap { UInt32(exactly: $0.windowNumber) }
    }

    func apply(_ desired: DesiredFocusDimSurface?) {
        guard let desired, !desired.displays.isEmpty else {
            scheduleHide()
            return
        }
        cancelPendingHide()
        guard desired != applied else { return }
        while panels.count < desired.displays.count {
            addPanel(frame: desired.displays[panels.count].frame)
        }
        while panels.count > desired.displays.count {
            removeLastPanel()
        }
        let opacity = CGFloat(desired.opacity)
        for (panel, display) in zip(panels, desired.displays) {
            if panel.frame != display.frame {
                panel.setFrame(display.frame, display: false)
                panel.resetHole()
            }
            let appearing = !panel.isVisible || panel.isFadingOut
            panel.setHole(
                display.hole,
                token: desired.token,
                cornerRadius: desired.holeCornerRadius,
                fadeDuration: appearing ? 0 : desired.fadeDuration
            )
            if abs(panel.alphaValue - opacity) > 0.001 {
                panel.alphaValue = opacity
            }
            if !panel.isVisible {
                panel.fadeIn(duration: desired.fadeDuration, fromTransparent: true)
                panel.orderFront(nil)
            } else if panel.isFadingOut {
                panel.fadeIn(duration: desired.fadeDuration)
            }
        }
        applied = desired
    }

    /// Hides the layer, fading it out when `applied` asked for fades.
    func hide(animated: Bool = true) {
        cancelPendingHide()
        let duration = animated ? applied?.fadeDuration ?? 0 : 0
        for panel in panels where panel.isVisible {
            if duration > 0 {
                panel.fadeOut(duration: duration) { [weak panel] in panel?.orderOut(nil) }
            } else {
                panel.orderOut(nil)
            }
        }
        applied = nil
    }

    var isHidePending: Bool {
        pendingHide != nil
    }

    private func scheduleHide() {
        guard applied != nil else { return }
        guard operations.hideDelay > .zero else {
            hide()
            return
        }
        guard pendingHide == nil else { return }
        let delay = operations.hideDelay
        pendingHide = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            pendingHide = nil
            hide()
        }
    }

    private func cancelPendingHide() {
        pendingHide?.cancel()
        pendingHide = nil
    }

    func cleanup() {
        hide(animated: false)
        while !panels.isEmpty {
            removeLastPanel()
        }
    }

    private func addPanel(frame: CGRect) {
        let panel = operations.createPanel(frame)
        let index = panels.count
        panels.append(panel)
        if let windowId = UInt32(exactly: panel.windowNumber), windowId != 0 {
            operations.excludeFromScreencaptureSelection(windowId)
        }
        surfaceCoordinator.register(
            window: panel,
            id: Self.surfaceIDPrefix + String(index),
            policy: SurfacePolicy(
                kind: .focusDim,
                hitTestPolicy: .passthrough,
                capturePolicy: .excluded,
                suppressesManagedFocusRecovery: false
            )
        )
    }

    private func removeLastPanel() {
        guard let panel = panels.popLast() else { return }
        surfaceCoordinator.unregister(id: Self.surfaceIDPrefix + String(panels.count))
        panel.orderOut(nil)
        panel.close()
    }
}
