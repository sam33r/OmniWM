// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation

extension IPCAutomationManifest {
    static let relativeWorkspaceCommandDescriptors: [IPCCommandDescriptor] = [
        .init(
            commandWords: ["switch-workspace", "new"],
            name: .workspace(.switchToNew),
            summary: "Create a new empty workspace on the interaction monitor and switch to it."
        ),
        .init(
            commandWords: ["move-to-workspace", "next"],
            name: .workspace(.moveNext),
            summary: "Move the focused window to the workspace that switch-workspace next would show."
        ),
        .init(
            commandWords: ["move-to-workspace", "prev"],
            name: .workspace(.movePrevious),
            summary: "Move the focused window to the workspace that switch-workspace prev would show."
        ),
        .init(
            commandWords: ["move-to-workspace", "new"],
            name: .workspace(.moveToNew),
            summary: "Move the focused window to a new workspace on its monitor and follow it there."
        )
    ]
}
