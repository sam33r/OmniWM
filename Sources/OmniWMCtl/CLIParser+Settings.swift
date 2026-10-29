// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation
import OmniWMIPC

extension CLIParser {
    static func parseSettingsRequest(id: String, arguments: [String]) throws -> IPCRequest {
        guard let actionToken = arguments.first,
              let action = IPCSettingsActionName(rawValue: actionToken),
              arguments.count >= 2
        else {
            throw CLIParseError.usage(usageText)
        }

        let key = arguments[1]
        let request: IPCSettingsRequest
        switch action {
        case .set:
            guard arguments.count >= 3 else {
                throw CLIParseError.usage(usageText)
            }
            request = .set(key: key, value: arguments.dropFirst(2).joined(separator: " "))
        case .toggle:
            guard arguments.count == 2 else {
                throw CLIParseError.usage(usageText)
            }
            request = .toggle(key: key)
        case .reset:
            guard arguments.count == 2 else {
                throw CLIParseError.usage(usageText)
            }
            request = .reset(key: key)
        }
        return IPCRequest(id: id, settings: request)
    }
}
