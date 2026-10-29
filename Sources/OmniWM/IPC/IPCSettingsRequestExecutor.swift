// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation
import OmniWMIPC

/// `omniwmctl settings set|toggle|reset`. Settings aren't commands: these work
/// while OmniWM is disabled and never answer `ignored_disabled`.
@MainActor
struct IPCSettingsRequestExecutor {
    private let controller: WMController

    init(controller: WMController) {
        self.controller = controller
    }

    func response(for request: IPCSettingsRequest, id: String) -> IPCResponse {
        switch perform(request) {
        case let .success(result):
            .success(id: id, kind: .settings, status: .executed, result: IPCResult(settingChange: result))
        case let .failure(failure):
            .failure(id: id, kind: .settings, code: failure.code, detail: failure.detail)
        }
    }

    /// Applies a change the way an edit of settings.toml is applied, then saves it
    /// through the settings store, so the file stays canonical and its watcher
    /// doesn't apply it a second time. Replies once the change is in effect.
    func perform(_ request: IPCSettingsRequest) -> Result<IPCSettingChangeResult, IPCSettingsFailure> {
        let settings = controller.settings
        let change: IPCSettingsChange
        let monitors = controller.workspaceManager.monitors
        switch IPCSettingsCatalog.change(request, in: settings.toExport(), monitorProvider: { monitors }) {
        case let .success(value):
            change = value
        case let .failure(failure):
            return .failure(failure)
        }
        if change.changesSettings {
            settings.applyExport(change.export)
            controller.applyPersistedSettings(settings, startServices: false)
            settings.scheduleSave()
        }
        return .success(IPCSettingChangeResult(
            key: change.key,
            value: IPCSettingsCatalog.value(of: change.key, in: settings.toExport()),
            previous: change.previous
        ))
    }
}
