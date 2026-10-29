// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import OmniWMIPC

extension WMController {
    /// Sends `settings-changed` subscribers a snapshot; a burst of changes (a
    /// slider drag, a reload) sends one.
    func publishSettingsChanged() {
        guard let ipcApplicationBridge, ipcApplicationBridge.hasSubscribers(for: .settingsChanged) else { return }
        Task {
            await ipcApplicationBridge.publishCoalescedEvent(.settingsChanged)
        }
    }
}
