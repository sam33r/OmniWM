// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

// Fork: settings over IPC (`omniwmctl query settings`, `omniwmctl settings
// set|toggle|reset`, `subscribe settings-changed`).

import Foundation

/// A setting's value on the wire: JSON of the setting's type, or `null` for an
/// unset optional setting.
public enum IPCSettingValue: Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case number(Double)
    case string(String)
    case null
}

extension IPCSettingValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else {
            self = try .string(container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public enum IPCSettingType: String, Codable, CaseIterable, Equatable, Sendable {
    case bool
    case int
    case number
    case enumeration = "enum"
    case string
}

public struct IPCSettingChoice: Codable, Equatable, Sendable {
    public let value: String
    public let title: String

    public init(value: String, title: String) {
        self.value = value
        self.title = title
    }
}

public struct IPCSettingDescriptor: Codable, Equatable, Sendable {
    public let key: String
    public let section: String
    public let sectionTitle: String
    public let title: String
    public let description: String
    public let type: IPCSettingType
    public let value: IPCSettingValue
    public let defaultValue: IPCSettingValue
    public let choices: [IPCSettingChoice]?
    public let min: Double?
    public let max: Double?
    public let step: Double?

    public init(
        key: String,
        section: String,
        sectionTitle: String,
        title: String,
        description: String,
        type: IPCSettingType,
        value: IPCSettingValue,
        defaultValue: IPCSettingValue,
        choices: [IPCSettingChoice]? = nil,
        min: Double? = nil,
        max: Double? = nil,
        step: Double? = nil
    ) {
        self.key = key
        self.section = section
        self.sectionTitle = sectionTitle
        self.title = title
        self.description = description
        self.type = type
        self.value = value
        self.defaultValue = defaultValue
        self.choices = choices
        self.min = min
        self.max = max
        self.step = step
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case section
        case sectionTitle
        case title
        case description
        case type
        case value
        case defaultValue = "default"
        case choices
        case min
        case max
        case step
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        section = try container.decode(String.self, forKey: .section)
        sectionTitle = try container.decode(String.self, forKey: .sectionTitle)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        type = try container.decode(IPCSettingType.self, forKey: .type)
        value = try container.decodeIfPresent(IPCSettingValue.self, forKey: .value) ?? .null
        defaultValue = try container.decodeIfPresent(IPCSettingValue.self, forKey: .defaultValue) ?? .null
        choices = try container.decodeIfPresent([IPCSettingChoice].self, forKey: .choices)
        min = try container.decodeIfPresent(Double.self, forKey: .min)
        max = try container.decodeIfPresent(Double.self, forKey: .max)
        step = try container.decodeIfPresent(Double.self, forKey: .step)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(section, forKey: .section)
        try container.encode(sectionTitle, forKey: .sectionTitle)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(type, forKey: .type)
        try container.encode(value, forKey: .value)
        try container.encode(defaultValue, forKey: .defaultValue)
        try container.encodeIfPresent(choices, forKey: .choices)
        try container.encodeIfPresent(min, forKey: .min)
        try container.encodeIfPresent(max, forKey: .max)
        try container.encodeIfPresent(step, forKey: .step)
    }
}

public struct IPCSettingsQueryResult: Codable, Equatable, Sendable {
    public let settings: [IPCSettingDescriptor]

    public init(settings: [IPCSettingDescriptor]) {
        self.settings = settings
    }
}

public enum IPCSettingsActionName: String, Codable, CaseIterable, Equatable, Sendable {
    case set
    case toggle
    case reset
}

public enum IPCSettingsRequest: Equatable, Sendable {
    /// `value` is the text as typed; OmniWM parses it by the setting's type.
    case set(key: String, value: String)
    case toggle(key: String)
    case reset(key: String)

    public var name: IPCSettingsActionName {
        switch self {
        case .set:
            .set
        case .toggle:
            .toggle
        case .reset:
            .reset
        }
    }

    public var key: String {
        switch self {
        case let .set(key, _),
             let .toggle(key),
             let .reset(key):
            key
        }
    }
}

extension IPCSettingsRequest: Codable {
    private enum CodingKeys: String, CodingKey {
        case name
        case key
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let action = try container.decode(IPCSettingsActionName.self, forKey: .name)
        let key = try container.decode(String.self, forKey: .key)
        let value = try container.decodeIfPresent(String.self, forKey: .value)

        switch action {
        case .set:
            guard let value else {
                throw DecodingError.keyNotFound(
                    CodingKeys.value,
                    .init(codingPath: container.codingPath, debugDescription: "set requires a value")
                )
            }
            self = .set(key: key, value: value)
        case .toggle,
             .reset:
            guard value == nil else {
                throw DecodingError.dataCorruptedError(
                    forKey: .value,
                    in: container,
                    debugDescription: "\(action.rawValue) does not accept a value"
                )
            }
            self = action == .toggle ? .toggle(key: key) : .reset(key: key)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(key, forKey: .key)
        if case let .set(_, value) = self {
            try container.encode(value, forKey: .value)
        }
    }
}

public struct IPCSettingChangeResult: Codable, Equatable, Sendable {
    public let key: String
    /// The value in effect after the change, after any clamping or rounding.
    public let value: IPCSettingValue
    public let previous: IPCSettingValue

    public init(key: String, value: IPCSettingValue, previous: IPCSettingValue) {
        self.key = key
        self.value = value
        self.previous = previous
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case value
        case previous
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        value = try container.decodeIfPresent(IPCSettingValue.self, forKey: .value) ?? .null
        previous = try container.decodeIfPresent(IPCSettingValue.self, forKey: .previous) ?? .null
    }
}

public struct IPCSettingsActionDescriptor: Codable, Equatable, Sendable {
    public let path: String
    public let name: IPCSettingsActionName
    public let summary: String
    public let arguments: [String]

    public init(path: String, name: IPCSettingsActionName, summary: String, arguments: [String] = []) {
        self.path = path
        self.name = name
        self.summary = summary
        self.arguments = arguments
    }
}
