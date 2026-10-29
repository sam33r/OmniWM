// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation

extension IPCAutomationManifest {
    public static let settingsActionDescriptors: [IPCSettingsActionDescriptor] = [
        .init(
            path: "settings set <key> <value>",
            name: .set,
            summary: "Validate a setting's new value, apply it live, and save it to settings.toml.",
            arguments: ["key", "value"]
        ),
        .init(
            path: "settings toggle <key>",
            name: .toggle,
            summary: "Flip a boolean setting, apply it live, and save it to settings.toml.",
            arguments: ["key"]
        ),
        .init(
            path: "settings reset <key>",
            name: .reset,
            summary: "Return a setting to its default, apply it live, and save it to settings.toml.",
            arguments: ["key"]
        )
    ]
}
