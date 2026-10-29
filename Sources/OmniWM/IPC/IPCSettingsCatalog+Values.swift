// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation
import OmniWMIPC

struct IPCSettingsFailure: Error, Equatable {
    let code: IPCErrorCode
    let detail: String
}

/// A validated change, ready to apply: the whole settings file as it would be
/// with the change, decoded with every check a load makes.
struct IPCSettingsChange {
    let key: String
    let export: SettingsExport
    let previous: IPCSettingValue
    /// False when the setting already has the requested value.
    let changesSettings: Bool
}

extension IPCSettingsCatalog {
    @MainActor private static let defaultTree: [String: TOMLNode] =
        (try? SettingsTOMLCodec.canonicalTree(SettingsStore.defaultExport)) ?? [:]

    /// Optional tables whose absence means "off, with these defaults": settings in
    /// them read as the defaults while the table is missing.
    private static let defaultedTables: Set<String> = ["borders.gradient", "borders.glow"]
    /// Optional tables whose keys are required together: setting one key in a
    /// missing table creates the whole table from its defaults first.
    private static let seededTables: Set<String> = defaultedTables.union(["quakeTerminal.kitty.placement"])

    /// The defaults with every optional table filled in, to seed missing tables from.
    @MainActor private static let seedTree: [String: TOMLNode] = {
        var export = SettingsStore.defaultExport
        export.borders.gradient = .default
        export.borders.glow = .default
        export.quakeTerminal.kitty = KittyQuakeSettings(placement: .defaultOverride)
        return (try? SettingsTOMLCodec.canonicalTree(export)) ?? [:]
    }()

    // MARK: Query

    @MainActor
    static func snapshot(of export: SettingsExport, key: String? = nil) -> IPCSettingsQueryResult {
        let current = (try? SettingsTOMLCodec.canonicalTree(export)) ?? [:]
        var settings: [IPCSettingDescriptor] = []
        for section in sections {
            for entry in section.entries where key == nil || entry.key == key {
                settings.append(descriptor(for: entry, in: section, current: current))
            }
        }
        return IPCSettingsQueryResult(settings: settings)
    }

    @MainActor
    static func value(of key: String, in export: SettingsExport) -> IPCSettingValue {
        guard let entry = entriesByKey[key]?.entry,
              let tree = try? SettingsTOMLCodec.canonicalTree(export)
        else { return .null }
        return value(of: effectiveNode(at: path(of: key), in: tree), kind: entry.kind)
    }

    /// Why `key` can't be read or changed over IPC, or nil when it can.
    @MainActor
    static func lookupFailure(for key: String, in export: SettingsExport) -> IPCSettingsFailure? {
        if entriesByKey[key] != nil, !notSettableKeys.contains(key) {
            return nil
        }
        let keyPath = path(of: key)
        let current = (try? SettingsTOMLCodec.canonicalTree(export)) ?? [:]
        if notSettableKeys.contains(key)
            || node(at: keyPath, in: current) != nil
            || node(at: keyPath, in: defaultTree) != nil
        {
            return IPCSettingsFailure(
                code: .notSettable,
                detail: "\(key) can't be changed over IPC; only the scalar settings in query settings can"
            )
        }
        return IPCSettingsFailure(code: .unknownSetting, detail: "no setting named \(key)")
    }

    @MainActor
    private static func descriptor(
        for entry: IPCSettingsCatalogEntry,
        in section: IPCSettingsCatalogSection,
        current: [String: TOMLNode]
    ) -> IPCSettingDescriptor {
        let keyPath = path(of: entry.key)
        let currentValue = value(of: effectiveNode(at: keyPath, in: current), kind: entry.kind)
        let defaultValue = value(of: effectiveNode(at: keyPath, in: defaultTree), kind: entry.kind)
        switch entry.kind {
        case .bool:
            return descriptor(entry, section, type: .bool, value: currentValue, defaultValue: defaultValue)
        case let .int(min, max, step):
            return descriptor(
                entry, section, type: .int, value: currentValue, defaultValue: defaultValue,
                min: min.map(Double.init), max: max.map(Double.init), step: step.map(Double.init)
            )
        case let .number(min, max, step):
            return descriptor(
                entry, section, type: .number, value: currentValue, defaultValue: defaultValue,
                min: min, max: max, step: step
            )
        case let .choice(choices):
            return descriptor(
                entry, section, type: .enumeration, value: currentValue, defaultValue: defaultValue,
                choices: choices.map { IPCSettingChoice(value: $0.value, title: $0.title) }
            )
        case .string:
            return descriptor(entry, section, type: .string, value: currentValue, defaultValue: defaultValue)
        }
    }

    private static func descriptor(
        _ entry: IPCSettingsCatalogEntry,
        _ section: IPCSettingsCatalogSection,
        type: IPCSettingType,
        value: IPCSettingValue,
        defaultValue: IPCSettingValue,
        choices: [IPCSettingChoice]? = nil,
        min: Double? = nil,
        max: Double? = nil,
        step: Double? = nil
    ) -> IPCSettingDescriptor {
        IPCSettingDescriptor(
            key: entry.key,
            section: section.id,
            sectionTitle: section.title,
            title: entry.title,
            description: entry.description,
            type: type,
            value: value,
            defaultValue: defaultValue,
            choices: choices,
            min: min,
            max: max,
            step: step
        )
    }

    // MARK: Changes

    /// Validates a change with every check a load of settings.toml makes: the
    /// decoder's, then the cross-setting ones (gesture finger counts, the
    /// Overview mouse button).
    @MainActor
    static func change(
        _ request: IPCSettingsRequest,
        in export: SettingsExport,
        monitorProvider: () -> [Monitor] = Monitor.current
    ) -> Result<IPCSettingsChange, IPCSettingsFailure> {
        let key = request.key
        if let failure = lookupFailure(for: key, in: export) {
            return .failure(failure)
        }
        guard let entry = entriesByKey[key]?.entry else {
            return .failure(IPCSettingsFailure(code: .unknownSetting, detail: "no setting named \(key)"))
        }
        let current: [String: TOMLNode]
        do {
            current = try SettingsTOMLCodec.canonicalTree(export)
        } catch {
            return .failure(IPCSettingsFailure(
                code: .internalError,
                detail: SettingsTOMLCodec.diagnosticDescription(for: error)
            ))
        }
        let keyPath = path(of: key)
        let currentNode = effectiveNode(at: keyPath, in: current)

        let newNode: TOMLNode?
        switch requestedNode(request, entry: entry, currentNode: currentNode, keyPath: keyPath) {
        case let .success(node):
            newNode = node
        case let .failure(failure):
            return .failure(failure)
        }

        let previous = value(of: currentNode, kind: entry.kind)
        var updated = current
        seedMissingTables(along: keyPath, in: &updated)
        setNode(newNode, at: keyPath, in: &updated)
        guard updated != current else {
            return .success(IPCSettingsChange(key: key, export: export, previous: previous, changesSettings: false))
        }
        do {
            let newExport = try SettingsTOMLCodec.decode(tree: updated)
            try OverviewInputSettingsValidation.validate(
                mouseButton: newExport.overview.mouseButton,
                hyperTrigger: newExport.systemHyperTrigger,
                hotkeyBindings: newExport.hotkeyBindings
            )
            try GestureSettingsValidation.validate(newExport, monitorProvider: monitorProvider)
            return .success(IPCSettingsChange(key: key, export: newExport, previous: previous, changesSettings: true))
        } catch {
            return .failure(IPCSettingsFailure(
                code: .invalidValue,
                detail: SettingsTOMLCodec.diagnosticDescription(for: error)
            ))
        }
    }

    /// The node the request asks for: nil to remove the key (back to unset).
    @MainActor
    private static func requestedNode(
        _ request: IPCSettingsRequest,
        entry: IPCSettingsCatalogEntry,
        currentNode: TOMLNode?,
        keyPath: [String]
    ) -> Result<TOMLNode?, IPCSettingsFailure> {
        switch request {
        case let .set(_, text):
            return parse(text, for: entry).map(Optional.some)
        case .toggle:
            guard case .bool = entry.kind else {
                return .failure(IPCSettingsFailure(
                    code: .invalidValue,
                    detail: "toggle only works on true/false settings; use settings set for \(entry.key)"
                ))
            }
            let isOn = if case let .boolean(value)? = currentNode ?? effectiveNode(at: keyPath, in: defaultTree) {
                value
            } else {
                false
            }
            return .success(.boolean(!isOn))
        case .reset:
            return .success(node(at: keyPath, in: defaultTree) ?? seededNode(at: keyPath))
        }
    }

    static func parse(_ text: String, for entry: IPCSettingsCatalogEntry) -> Result<TOMLNode, IPCSettingsFailure> {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        func invalid(_ detail: String) -> Result<TOMLNode, IPCSettingsFailure> {
            .failure(IPCSettingsFailure(code: .invalidValue, detail: detail))
        }
        switch entry.kind {
        case .bool:
            switch trimmed.lowercased() {
            case "true":
                return .success(.boolean(true))
            case "false":
                return .success(.boolean(false))
            default:
                return invalid("must be true or false")
            }
        case let .int(min, max, _):
            guard let value = Int(trimmed) else {
                return invalid("must be a whole number")
            }
            if let detail = rangeFailure(Double(value), min: min.map(Double.init), max: max.map(Double.init)) {
                return invalid(detail)
            }
            return .success(.integer(Int64(value)))
        case let .number(min, max, _):
            guard let value = Double(trimmed), value.isFinite else {
                return invalid("must be a number")
            }
            if let detail = rangeFailure(value, min: min, max: max) {
                return invalid(detail)
            }
            return .success(.float(value))
        case let .choice(choices):
            guard choices.contains(where: { $0.value == trimmed }) else {
                return invalid("must be one of " + choices.map(\.value).joined(separator: ", "))
            }
            return .success(.string(trimmed))
        case .string:
            return .success(.string(text))
        }
    }

    private static func rangeFailure(_ value: Double, min: Double?, max: Double?) -> String? {
        switch (min, max) {
        case let (min?, max?) where value < min || value > max:
            "must be between \(formatted(min)) and \(formatted(max))"
        case let (min?, nil) where value < min:
            "must be at least \(formatted(min))"
        case let (nil, max?) where value > max:
            "must be at most \(formatted(max))"
        default:
            nil
        }
    }

    private static func formatted(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int(value))
        }
        return String(value)
    }

    // MARK: Tree access

    static func path(of key: String) -> [String] {
        key.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    }

    static func node(at path: [String], in tree: [String: TOMLNode]) -> TOMLNode? {
        guard let first = path.first, let node = tree[first] else { return nil }
        let rest = Array(path.dropFirst())
        if rest.isEmpty {
            return node
        }
        guard case let .table(table) = node else { return nil }
        return self.node(at: rest, in: table)
    }

    /// The node at `path`, or its default while it sits in a missing defaulted table.
    @MainActor
    static func effectiveNode(at path: [String], in tree: [String: TOMLNode]) -> TOMLNode? {
        if let node = node(at: path, in: tree) {
            return node
        }
        for length in 1 ..< max(path.count, 1) {
            let table = Array(path.prefix(length))
            if defaultedTables.contains(table.joined(separator: ".")), node(at: table, in: tree) == nil {
                return node(at: path, in: seedTree)
            }
        }
        return nil
    }

    @MainActor
    private static func seededNode(at path: [String]) -> TOMLNode? {
        let isSeeded = (1 ..< max(path.count, 1)).contains {
            seededTables.contains(path.prefix($0).joined(separator: "."))
        }
        return isSeeded ? node(at: path, in: seedTree) : nil
    }

    @MainActor
    private static func seedMissingTables(along path: [String], in tree: inout [String: TOMLNode]) {
        for length in 1 ..< max(path.count, 1) {
            let table = Array(path.prefix(length))
            guard seededTables.contains(table.joined(separator: ".")), node(at: table, in: tree) == nil,
                  let seed = node(at: table, in: seedTree)
            else { continue }
            setNode(seed, at: table, in: &tree)
        }
    }

    static func setNode(_ node: TOMLNode?, at path: [String], in tree: inout [String: TOMLNode]) {
        guard let first = path.first else { return }
        let rest = Array(path.dropFirst())
        if rest.isEmpty {
            tree[first] = node
            return
        }
        var table: [String: TOMLNode] = if case let .table(existing)? = tree[first] { existing } else { [:] }
        setNode(node, at: rest, in: &table)
        tree[first] = .table(table)
    }

    static func value(of node: TOMLNode?, kind: IPCSettingsCatalogEntry.Kind) -> IPCSettingValue {
        switch (kind, node) {
        case let (.bool, .boolean(value)?):
            .bool(value)
        case let (.int, .integer(value)?):
            Int(exactly: value).map(IPCSettingValue.int) ?? .null
        case let (.number, .float(value)?):
            .number(value)
        case let (.number, .integer(value)?):
            .number(Double(value))
        case let (.choice, .string(value)?),
             let (.string, .string(value)?):
            .string(value)
        default:
            .null
        }
    }
}
