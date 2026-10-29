// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation

extension IPCJSONWriter {
    mutating func value(_ value: borrowing IPCProcessResourceMetrics) throws {
        begin(123)
        var first = true
        self.key("energyNanojoules", &first)
        try self.value(value.energyNanojoules)
        self.key("interruptWakeups", &first)
        try self.value(value.interruptWakeups)
        self.key("packageIdleWakeups", &first)
        try self.value(value.packageIdleWakeups)
        self.key("physicalFootprintBytes", &first)
        try self.value(value.physicalFootprintBytes)
        self.key("residentSizeBytes", &first)
        try self.value(value.residentSizeBytes)
        self.key("systemTimeNanoseconds", &first)
        try self.value(value.systemTimeNanoseconds)
        self.key("userTimeNanoseconds", &first)
        try self.value(value.userTimeNanoseconds)
        end(125)
    }

    mutating func value(_ value: borrowing IPCMetricsQueryResult) throws {
        begin(123)
        var first = true
        self.key("axWrites", &first)
        try self.value(value.axWrites)
        self.key("displayTicks", &first)
        try self.value(value.displayTicks)
        self.key("layoutBuilds", &first)
        try self.value(value.layoutBuilds)
        if let fieldValue = value.process {
            self.key("process", &first)
            try self.value(fieldValue)
        }
        self.key("traceCaptureActive", &first)
        try self.value(value.traceCaptureActive)
        end(125)
    }

    mutating func value(_ value: borrowing IPCShellWidget) throws {
        begin(123)
        var first = true
        if let fieldValue = value.error {
            self.key("error", &first)
            try self.value(fieldValue)
        }
        self.key("name", &first)
        try self.value(value.name)
        self.key("placements", &first)
        try self.value(value.placements)
        self.key("source", &first)
        try self.value(value.source)
        self.key("state", &first)
        try self.value(value.state)
        end(125)
    }

    mutating func value(_ value: borrowing [IPCShellWidget]) throws {
        begin(91)
        var first = true
        let span = value.span
        var index = 0
        while index < span.count {
            item(&first)
            try self.value(span[index])
            index += 1
        }
        end(93)
    }

    mutating func value(_ value: borrowing IPCShellWidgetsQueryResult) throws {
        begin(123)
        var first = true
        self.key("problems", &first)
        try self.value(value.problems)
        self.key("profile", &first)
        try self.value(value.profile)
        self.key("widgets", &first)
        try self.value(value.widgets)
        end(125)
    }

    mutating func value(_ value: borrowing IPCSettingChoice) throws {
        begin(123)
        var first = true
        self.key("title", &first)
        try self.value(value.title)
        self.key("value", &first)
        try self.value(value.value)
        end(125)
    }

    mutating func value(_ value: borrowing [IPCSettingChoice]) throws {
        begin(91)
        var first = true
        let span = value.span
        var index = 0
        while index < span.count {
            item(&first)
            try self.value(span[index])
            index += 1
        }
        end(93)
    }

    mutating func value(_ value: borrowing IPCSettingValue) throws {
        switch value {
        case let .bool(fieldValue):
            try self.value(fieldValue)
        case let .int(fieldValue):
            try self.value(fieldValue)
        case let .number(fieldValue):
            try self.value(fieldValue)
        case let .string(fieldValue):
            try self.value(fieldValue)
        case .null:
            raw("null")
        }
    }

    mutating func value(_ value: borrowing IPCSettingType) throws {
        try self.value(value.rawValue)
    }

    mutating func value(_ value: borrowing IPCSettingDescriptor) throws {
        begin(123)
        var first = true
        if let fieldValue = value.choices {
            self.key("choices", &first)
            try self.value(fieldValue)
        }
        self.key("default", &first)
        try self.value(value.defaultValue)
        self.key("description", &first)
        try self.value(value.description)
        self.key("key", &first)
        try self.value(value.key)
        if let fieldValue = value.max {
            self.key("max", &first)
            try self.value(fieldValue)
        }
        if let fieldValue = value.min {
            self.key("min", &first)
            try self.value(fieldValue)
        }
        self.key("section", &first)
        try self.value(value.section)
        self.key("sectionTitle", &first)
        try self.value(value.sectionTitle)
        if let fieldValue = value.step {
            self.key("step", &first)
            try self.value(fieldValue)
        }
        self.key("title", &first)
        try self.value(value.title)
        self.key("type", &first)
        try self.value(value.type)
        self.key("value", &first)
        try self.value(value.value)
        end(125)
    }

    mutating func value(_ value: borrowing [IPCSettingDescriptor]) throws {
        begin(91)
        var first = true
        let span = value.span
        var index = 0
        while index < span.count {
            item(&first)
            try self.value(span[index])
            index += 1
        }
        end(93)
    }

    mutating func value(_ value: borrowing IPCSettingsQueryResult) throws {
        begin(123)
        var first = true
        self.key("settings", &first)
        try self.value(value.settings)
        end(125)
    }

    mutating func value(_ value: borrowing IPCSettingChangeResult) throws {
        begin(123)
        var first = true
        self.key("key", &first)
        try self.value(value.key)
        self.key("previous", &first)
        try self.value(value.previous)
        self.key("value", &first)
        try self.value(value.value)
        end(125)
    }

    mutating func value(_ value: borrowing IPCResult.Payload) throws {
        switch value {
        case let .pong(payload):
            try self.value(payload)
        case let .version(payload):
            try self.value(payload)
        case let .capture(payload):
            try self.value(payload)
        case let .workspaceBar(payload):
            try self.value(payload)
        case let .activeWorkspace(payload):
            try self.value(payload)
        case let .focusedMonitor(payload):
            try self.value(payload)
        case let .apps(payload):
            try self.value(payload)
        case let .focusedWindow(payload):
            try self.value(payload)
        case let .windows(payload):
            try self.value(payload)
        case let .workspaces(payload):
            try self.value(payload)
        case let .displays(payload):
            try self.value(payload)
        case let .rules(payload):
            try self.value(payload)
        case let .ruleActions(payload):
            try self.value(payload)
        case let .queries(payload):
            try self.value(payload)
        case let .commands(payload):
            try self.value(payload)
        case let .subscriptions(payload):
            try self.value(payload)
        case let .capabilities(payload):
            try self.value(payload)
        case let .subscribed(payload):
            try self.value(payload)
        case let .windowMarks(payload):
            try self.value(payload)
        case let .windowGather(payload):
            try self.value(payload)
        case let .metrics(payload):
            try self.value(payload)
        case let .shellWidgets(payload):
            try self.value(payload)
        case let .settings(payload):
            try self.value(payload)
        case let .settingChange(payload):
            try self.value(payload)
        }
    }

    mutating func value(_ value: borrowing IPCResult) throws {
        begin(123)
        var first = true
        self.key("kind", &first)
        try self.value(value.kind)
        self.key("payload", &first)
        try self.value(value.payload)
        end(125)
    }
}
