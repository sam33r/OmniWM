// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

// Fork: this fork doesn't link GhosttyKit, so the Ghostty-backed Quake terminal
// is compiled out (see `ghosttyQuakeTerminalSources` in Package.swift). This
// stand-in keeps the controller interface the rest of the app calls and does
// nothing; the Kitty Quick Access provider is unaffected.

import Cocoa

enum QuakeTerminalRestoreTarget: Equatable {
    case managed(WindowToken)
    case external(KeyboardFocusTarget)
}

@MainActor
final class QuakeTerminalController: NSObject {
    /// Never created: there is no Ghostty terminal window in this fork.
    let window: QuakeTerminalWindow? = nil

    init(
        settings _: SettingsStore,
        motionPolicy _: MotionPolicy,
        captureRestoreTarget _: @escaping @MainActor () -> QuakeTerminalRestoreTarget? = { nil },
        restoreFocusTarget _: @escaping @MainActor (QuakeTerminalRestoreTarget) -> Void = { _ in },
        isWindowFocused _: @escaping @MainActor (NSWindow) -> Bool = { $0.isKeyWindow },
        focusedWindowScreenProvider _: @escaping @MainActor () -> NSScreen? = { nil }
    ) {
        super.init()
    }

    func setup() {}

    func cleanup() {}

    func toggle() {}

    func hideForProviderSwitch() {}

    func applyGeometryToVisibleWindow() {}

    func reloadOpacityConfig() {}

    func reloadBackgroundBlur() {}
}
