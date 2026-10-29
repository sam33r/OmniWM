// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

// Fork: one display's dark layer for `[focus] dimUnfocused` (see FocusDim.swift).

import AppKit
import QuartzCore

@MainActor
class FocusDimPanel: NSPanel {
    /// Above every normal window, below floating panels, menus and bars.
    static let dimLevel = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)

    /// A window cut out of the dark layer. Its patch is a dark shape over the part of
    /// the cut-out no other cut-out claims; fading the patch's opacity brightens or
    /// darkens that window without a hard switch.
    private final class Cutout {
        let token: WindowToken
        var rect: CGRect
        let patch = CAShapeLayer()
        var fadeGeneration = 0

        init(token: WindowToken, rect: CGRect, opacity: Float) {
            self.token = token
            self.rect = rect
            patch.fillColor = NSColor.black.cgColor
            patch.opacity = opacity
            patch.actions = ["path": NSNull(), "opacity": NSNull(), "bounds": NSNull(), "position": NSNull()]
        }
    }

    private let rootLayer = CALayer()
    private let dimLayer = CALayer()
    private let holeMask = CAShapeLayer()
    /// The bright window on this display.
    private var current: Cutout?
    /// Windows that were bright and are fading back to dark.
    private var fading: [Cutout] = []
    /// The window the hole belongs to, also while it's on another display.
    private var holeToken: WindowToken?
    private(set) var hole: CGRect?
    private var holeCornerRadius: CGFloat = 0
    private var visibilityGeneration = 0
    private(set) var isFadingOut = false

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
        rootLayer.actions = ["bounds": NSNull(), "position": NSNull(), "opacity": NSNull(), "sublayers": NSNull()]
        dimLayer.backgroundColor = NSColor.black.cgColor
        dimLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        dimLayer.frame = view.bounds
        dimLayer.actions = ["bounds": NSNull(), "position": NSNull(), "mask": NSNull()]
        holeMask.fillRule = .evenOdd
        holeMask.actions = ["path": NSNull(), "bounds": NSNull(), "position": NSNull()]
        rootLayer.addSublayer(dimLayer)
        view.layer = rootLayer
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

    /// Windows still fading back to dark.
    var fadingHoleCount: Int {
        fading.count
    }

    /// Cuts `hole` (AppKit coordinates), the frame of `token`'s window on this display,
    /// out of the dark layer. When the bright window changes, the old one fades to
    /// dark while the new one fades in; a moving or resizing window follows at once.
    func setHole(_ hole: CGRect?, token: WindowToken, cornerRadius: CGFloat, fadeDuration: Double = 0) {
        let local = hole.map { $0.offsetBy(dx: -frame.minX, dy: -frame.minY) }
        guard hole != self.hole || token != holeToken || cornerRadius != holeCornerRadius
            || holeMask.frame != dimLayer.bounds
        else { return }
        self.hole = hole
        holeCornerRadius = cornerRadius
        if fadeDuration <= 0 {
            removeFadingCutouts()
            replaceCurrent(with: local.map { Cutout(token: token, rect: $0, opacity: 0) })
        } else if token == holeToken {
            if let local, let current {
                current.rect = local
            } else {
                replaceCurrent(with: local.map { Cutout(token: token, rect: $0, opacity: 0) })
            }
        } else {
            if let previous = current {
                fading.append(previous)
                fade(previous, to: 1, duration: fadeDuration)
            }
            current = nil
            if let local {
                let next: Cutout
                if let index = fading.firstIndex(where: { $0.token == token }) {
                    next = fading.remove(at: index)
                    next.rect = local
                } else {
                    next = Cutout(token: token, rect: local, opacity: 1)
                }
                current = next
                fade(next, to: 0, duration: fadeDuration)
            }
        }
        holeToken = token
        rebuildCutouts()
    }

    /// Drops all cut-outs, as after the panel moved to another display's frame.
    func resetHole() {
        removeFadingCutouts()
        replaceCurrent(with: nil)
        hole = nil
        holeToken = nil
        rebuildCutouts()
    }

    /// Fades the layer in, from fully transparent when `fromTransparent`.
    func fadeIn(duration: Double, fromTransparent: Bool = false) {
        visibilityGeneration += 1
        isFadingOut = false
        if fromTransparent {
            rootLayer.removeAnimation(forKey: "visibility")
            rootLayer.opacity = 0
        }
        animateRoot(to: 1, duration: duration)
    }

    /// Fades the layer out, then calls `completion` unless it was faded in meanwhile.
    func fadeOut(duration: Double, completion: @escaping @MainActor () -> Void) {
        visibilityGeneration += 1
        let generation = visibilityGeneration
        isFadingOut = true
        animateRoot(to: 0, duration: duration)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self, visibilityGeneration == generation else { return }
            isFadingOut = false
            completion()
        }
    }

    private func animateRoot(to target: Float, duration: Double) {
        let from = rootLayer.animation(forKey: "visibility") == nil
            ? rootLayer.opacity
            : rootLayer.presentation()?.opacity ?? rootLayer.opacity
        rootLayer.removeAnimation(forKey: "visibility")
        rootLayer.opacity = target
        guard duration > 0, from != target else { return }
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = from
        animation.toValue = target
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        rootLayer.add(animation, forKey: "visibility")
    }

    private func fade(_ cutout: Cutout, to target: Float, duration: Double) {
        let from = cutout.patch.animation(forKey: "fade") == nil
            ? cutout.patch.opacity
            : cutout.patch.presentation()?.opacity ?? cutout.patch.opacity
        cutout.patch.removeAnimation(forKey: "fade")
        cutout.patch.opacity = target
        cutout.fadeGeneration += 1
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = from
        animation.toValue = target
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cutout.patch.add(animation, forKey: "fade")
        guard target == 1 else { return }
        let generation = cutout.fadeGeneration
        Task { @MainActor [weak self, weak cutout] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self, let cutout, cutout.fadeGeneration == generation,
                  let index = fading.firstIndex(where: { $0 === cutout })
            else { return }
            fading.remove(at: index)
            cutout.patch.removeFromSuperlayer()
            rebuildCutouts()
        }
    }

    private func replaceCurrent(with cutout: Cutout?) {
        current?.patch.removeFromSuperlayer()
        current = cutout
    }

    private func removeFadingCutouts() {
        for cutout in fading {
            cutout.patch.removeFromSuperlayer()
        }
        fading.removeAll()
    }

    private func rebuildCutouts() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let bounds = dimLayer.bounds
        let cutouts = (current.map { [$0] } ?? []) + fading
        guard !cutouts.isEmpty else {
            dimLayer.mask = nil
            return
        }
        let shapes = cutouts.map { roundedPath($0.rect) }
        let holes = CGMutablePath()
        shapes.forEach { holes.addPath($0) }
        holeMask.frame = bounds
        holeMask.path = CGPath(rect: bounds, transform: nil).subtracting(holes)
        dimLayer.mask = holeMask

        let currentShape = current.map { roundedPath($0.rect) }
        let fadingShapes = CGMutablePath()
        shapes.dropFirst(current == nil ? 0 : 1).forEach { fadingShapes.addPath($0) }
        for (cutout, shape) in zip(cutouts, shapes) {
            if cutout.patch.superlayer == nil {
                rootLayer.addSublayer(cutout.patch)
            }
            cutout.patch.frame = bounds
            if cutout === current {
                // Where it overlaps a window fading out, it was already bright.
                cutout.patch.path = shape.subtracting(fadingShapes)
            } else {
                cutout.patch.path = currentShape.map { shape.subtracting($0) } ?? shape
            }
        }
    }

    private func roundedPath(_ rect: CGRect) -> CGPath {
        let radius = min(holeCornerRadius, rect.width / 2, rect.height / 2)
        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }
}
