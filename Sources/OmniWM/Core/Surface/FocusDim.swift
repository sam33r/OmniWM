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
}

extension SurfaceDerivation {
    /// Follows the border's notion of the focused window, but only while that window
    /// itself has native focus: with nothing managed to keep bright (an unmanaged app,
    /// the desktop, an OmniWM panel, a dialog outside its parent) nothing is dimmed.
    /// The hole always uses the window's live bounds when available, also during
    /// animations: mixing in requested frames, which apps such as terminals round to
    /// their own size steps, made the hole's edges flicker between the two.
    @MainActor
    static func deriveFocusDim(world: WorldView) -> DesiredFocusDimSurface? {
        let settings = world.focusDimSettings
        guard settings.enabled, world.hasStartedServices,
              let token = world.borderFocusToken,
              world.nativeManagedFocusToken == token,
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
        return DesiredFocusDimSurface(
            token: token,
            displays: displays,
            holeCornerRadius: radius,
            opacity: settings.opacity
        )
    }
}

@MainActor
class FocusDimPanel: NSPanel {
    /// Above every normal window, below floating panels, menus and bars.
    static let dimLevel = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)

    private let dimLayer = CALayer()
    private let holeMask = CAShapeLayer()
    private(set) var hole: CGRect?
    private var holeCornerRadius: CGFloat = 0

    init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        alphaValue = 0
        ignoresMouseEvents = true
        hasShadow = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        isRestorable = false
        level = Self.dimLevel

        let view = NSView(frame: CGRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        dimLayer.backgroundColor = NSColor.black.cgColor
        dimLayer.actions = ["bounds": NSNull(), "position": NSNull(), "mask": NSNull()]
        holeMask.fillRule = .evenOdd
        holeMask.actions = ["path": NSNull(), "bounds": NSNull(), "position": NSNull()]
        view.layer = dimLayer
        contentView = view
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    override func constrainFrameRect(_ frameRect: NSRect, to _: NSScreen?) -> NSRect {
        frameRect
    }

    /// Cuts `hole` (AppKit coordinates) out of the dark layer.
    func setHole(_ hole: CGRect?, cornerRadius: CGFloat) {
        guard hole != self.hole || cornerRadius != holeCornerRadius || holeMask.frame != dimLayer.bounds else {
            return
        }
        self.hole = hole
        holeCornerRadius = cornerRadius
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard let hole else {
            dimLayer.mask = nil
            return
        }
        let bounds = dimLayer.bounds
        let local = hole.offsetBy(dx: -frame.minX, dy: -frame.minY)
        let radius = min(cornerRadius, local.width / 2, local.height / 2)
        let path = CGMutablePath()
        path.addRect(bounds)
        path.addRoundedRect(in: local, cornerWidth: radius, cornerHeight: radius)
        holeMask.frame = bounds
        holeMask.path = path
        dimLayer.mask = holeMask
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
            }
            panel.setHole(display.hole, cornerRadius: desired.holeCornerRadius)
            if abs(panel.alphaValue - opacity) > 0.001 {
                panel.alphaValue = opacity
            }
            if !panel.isVisible {
                panel.orderFront(nil)
            }
        }
        applied = desired
    }

    func hide() {
        cancelPendingHide()
        for panel in panels where panel.isVisible {
            panel.orderOut(nil)
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
        hide()
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
