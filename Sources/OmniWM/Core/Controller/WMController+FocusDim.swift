// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation

extension WMController {
    /// Fork: flips `[focus] dimUnfocused` (saved like any settings change) and
    /// shows or hides the dim layer on the next border pass.
    @discardableResult
    func toggleDimUnfocused() -> Bool {
        settings.focus.dimUnfocused.toggle()
        focusDimSettingsChanged()
        return settings.focus.dimUnfocused
    }

    func focusDimSettingsChanged() {
        surfaceReconciler.noteBorderChanged()
    }
}
