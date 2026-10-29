// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

// Fork: the settings `omniwmctl query settings` lists and `omniwmctl settings`
// changes. Only scalar settings are listed (no lists, colour tables, or
// per-monitor/per-workspace entries), in the order the Settings window shows
// them. Values and defaults come from the canonical TOML tree, so the keys are
// the `settings.toml` paths; this catalog adds what the tree can't say: titles,
// descriptions, ranges, and enum choices.

struct IPCSettingsCatalogSection {
    /// The `settings.toml` table, the first component of every key in it.
    let id: String
    let title: String
    let entries: [IPCSettingsCatalogEntry]
}

struct IPCSettingsCatalogEntry {
    struct Choice: Equatable {
        let value: String
        let title: String
    }

    enum Kind {
        case bool
        case int(min: Int? = nil, max: Int? = nil, step: Int? = nil)
        case number(min: Double? = nil, max: Double? = nil, step: Double? = nil)
        /// A closed set of strings, in the order the Settings window lists them.
        case choice([Choice])
        case string
    }

    /// `<section>.<key>` (or `<section>.<table>.<key>`), as in `settings.toml`.
    let key: String
    let title: String
    let description: String
    let kind: Kind

    init(_ key: String, _ title: String, _ kind: Kind, _ description: String) {
        self.key = key
        self.title = title
        self.kind = kind
        self.description = description
    }
}

enum IPCSettingsCatalog {
    /// Keys that exist in `settings.toml` as scalars but must never be changed over IPC.
    static let notSettableKeys: Set<String> = [
        "schemaVersion",
        // Turning IPC off from an IPC client would cut that client off.
        "general.ipcEnabled"
    ]

    static let entriesByKey: [String: (section: IPCSettingsCatalogSection, entry: IPCSettingsCatalogEntry)] = {
        var result: [String: (section: IPCSettingsCatalogSection, entry: IPCSettingsCatalogEntry)] = [:]
        for section in sections {
            for entry in section.entries {
                result[entry.key] = (section, entry)
            }
        }
        return result
    }()
}
