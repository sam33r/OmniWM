// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation
@testable import OmniWM
import TOML
import XCTest

final class FocusRoutingSettingsExportTests: XCTestCase {
    func testDefaultSectionsKeepCanonicalTableShapeAndValues() throws {
        let defaults = SettingsExport.defaults()
        let data = try SettingsTOMLCodec.encode(defaults)
        let tree = try TOMLDecoder().decode([String: TOMLNode].self, from: data)

        XCTAssertEqual(tree["focus"], .table([
            "followsMouse": .boolean(false),
            "edgeNavigationInterval": .float(1.5),
            "raiseOnMouseFocus": .boolean(false),
            "lockModifier": .string("off"),
            "moveMouseToFocusedWindow": .boolean(false),
            "followsWindowToMonitor": .boolean(false),
            "crossesMonitorAtEdge": .boolean(false),
            "moveCrossesMonitorAtEdge": .boolean(false),
            "moveToMonitorWrapsAround": .boolean(false),
            "relativeWorkspaceEdgeBehavior": .string("cycle"),
            "dimUnfocused": .boolean(false),
            "dimUnfocusedOpacity": .float(0.6)
        ]))
        XCTAssertEqual(tree["mouseWarp"], .table([
            "margin": .integer(1),
            "enabled": .boolean(true),
            "constrainToArrangement": .boolean(false)
        ]))
        XCTAssertEqual(tree["routing"], .table([
            "mode": .string("macOS"),
            "arrangements": .array([])
        ]))
        XCTAssertEqual(try SettingsTOMLCodec.decode(data), defaults)
    }

    func testEveryEdgeNavigationIntervalRoundTrips() throws {
        var export = SettingsExport.defaults()
        for interval in stride(from: 0.25, through: 2.0, by: 0.25) {
            export.focus.edgeNavigationInterval = interval
            let data = try SettingsTOMLCodec.encode(export)
            let result = try SettingsTOMLCodec.decodeForLoad(data)
            XCTAssertEqual(result.export, export)
            XCTAssertNil(result.migration)
            XCTAssertNil(result.migratedData)
            XCTAssertFalse(SettingsTOMLCodec.unknownKeyPaths(in: data).contains("focus.edgeNavigationInterval"))
        }
    }

    func testEdgeNavigationIntervalNormalizesAtTOMLBoundary() throws {
        let source = String(decoding: try SettingsTOMLCodec.encode(.defaults()), as: UTF8.self)
        for (literal, expected) in [
            ("0", 0.25), ("-1.0", 0.25), ("0.374", 0.25), ("0.375", 0.5),
            ("1.375", 1.5), ("3.0", 2.0), ("nan", 1.5), ("inf", 1.5), ("-inf", 1.5)
        ] {
            let data = Data(source.replacingOccurrences(
                of: "edgeNavigationInterval = 1.5",
                with: "edgeNavigationInterval = \(literal)"
            ).utf8)
            XCTAssertEqual(try SettingsTOMLCodec.decode(data).focus.edgeNavigationInterval, expected, literal)
        }
        var export = SettingsExport.defaults()
        for (value, expected) in [(Double.nan, 1.5), (.infinity, 1.5), (-2.0, 0.25), (1.375, 1.5), (4.0, 2.0)] {
            export.focus.edgeNavigationInterval = value
            let data = try SettingsTOMLCodec.encode(export)
            XCTAssertEqual(try SettingsTOMLCodec.decode(data).focus.edgeNavigationInterval, expected)
        }
    }

    func testOmittedEdgeNavigationIntervalUsesDefaultAndMalformedValueFails() throws {
        let source = String(decoding: try SettingsTOMLCodec.encode(.defaults()), as: UTF8.self)
        let missing = try removing(key: "edgeNavigationInterval", from: "focus", in: source)
        let result = try SettingsTOMLCodec.decodeForLoad(Data(missing.utf8))
        XCTAssertEqual(result.export.focus.edgeNavigationInterval, 1.5)
        XCTAssertNil(result.migration)
        XCTAssertNil(result.migratedData)

        let malformed = source.replacingOccurrences(
            of: "edgeNavigationInterval = 1.5",
            with: "edgeNavigationInterval = \"1.5\""
        )
        XCTAssertThrowsError(try SettingsTOMLCodec.decode(Data(malformed.utf8))) { error in
            guard case let DecodingError.typeMismatch(_, context) = error else {
                return XCTFail("Expected an invalid interval type, got \(error)")
            }
            XCTAssertEqual(context.codingPath.map(\.stringValue), ["focus", "edgeNavigationInterval"])
        }
    }

    func testMoveToMonitorWrapAroundIsOptionalAndRoundTrips() throws {
        XCTAssertFalse(SettingsExport.defaults().focus.moveToMonitorWrapsAround)
        for wraps in [false, true] {
            var export = SettingsExport.defaults()
            export.focus.moveToMonitorWrapsAround = wraps
            let data = try SettingsTOMLCodec.encode(export)
            let result = try SettingsTOMLCodec.decodeForLoad(data)
            XCTAssertEqual(result.export, export)
            XCTAssertNil(result.migration)
            XCTAssertTrue(SettingsTOMLCodec.unknownKeyPaths(in: data).isEmpty)
        }

        let source = String(decoding: try SettingsTOMLCodec.encode(.defaults()), as: UTF8.self)
        let missing = try removing(key: "moveToMonitorWrapsAround", from: "focus", in: source)
        let result = try SettingsTOMLCodec.decodeForLoad(Data(missing.utf8))
        XCTAssertFalse(result.export.focus.moveToMonitorWrapsAround)
        XCTAssertNil(result.migration)
        XCTAssertNil(result.migratedData)

        let malformed = source.replacingOccurrences(
            of: "moveToMonitorWrapsAround = false",
            with: "moveToMonitorWrapsAround = 1"
        )
        XCTAssertThrowsError(try SettingsTOMLCodec.decode(Data(malformed.utf8)))
    }

    func testFollowsMouseMaxScrollPercentIsOptionalUnlimitedAndClamped() throws {
        XCTAssertNil(SettingsExport.defaults().focus.followsMouseMaxScrollPercent)
        let source = String(decoding: try SettingsTOMLCodec.encode(.defaults()), as: UTF8.self)
        XCTAssertFalse(source.contains("followsMouseMaxScrollPercent"))
        let unchanged = try SettingsTOMLCodec.decodeForLoad(Data(source.utf8))
        XCTAssertNil(unchanged.export.focus.followsMouseMaxScrollPercent)
        XCTAssertNil(unchanged.migration)
        XCTAssertNil(unchanged.migratedData)

        var export = SettingsExport.defaults()
        for percent in [0, 30, 100] {
            export.focus.followsMouseMaxScrollPercent = percent
            let data = try SettingsTOMLCodec.encode(export)
            let tree = try TOMLDecoder().decode([String: TOMLNode].self, from: data)
            guard case let .table(focus)? = tree["focus"] else { return XCTFail("Missing focus table") }
            XCTAssertEqual(focus["followsMouseMaxScrollPercent"], .integer(Int64(percent)))
            let result = try SettingsTOMLCodec.decodeForLoad(data)
            XCTAssertEqual(result.export, export)
            XCTAssertNil(result.migration)
            XCTAssertFalse(SettingsTOMLCodec.unknownKeyPaths(in: data).contains("focus.followsMouseMaxScrollPercent"))
        }

        for (literal, expected) in [("-5", 0), ("0", 0), ("45", 45), ("250", 100)] {
            let data = Data(source.replacingOccurrences(
                of: "[focus]\n",
                with: "[focus]\nfollowsMouseMaxScrollPercent = \(literal)\n"
            ).utf8)
            XCTAssertEqual(try SettingsTOMLCodec.decode(data).focus.followsMouseMaxScrollPercent, expected, literal)
        }
        export.focus.followsMouseMaxScrollPercent = 140
        XCTAssertEqual(
            try SettingsTOMLCodec.decode(SettingsTOMLCodec.encode(export)).focus.followsMouseMaxScrollPercent,
            100
        )

        let malformed = source.replacingOccurrences(
            of: "[focus]\n",
            with: "[focus]\nfollowsMouseMaxScrollPercent = \"50%\"\n"
        )
        XCTAssertThrowsError(try SettingsTOMLCodec.decode(Data(malformed.utf8))) { error in
            guard case let DecodingError.typeMismatch(_, context) = error else {
                return XCTFail("Expected an invalid percentage type, got \(error)")
            }
            XCTAssertEqual(context.codingPath.map(\.stringValue), ["focus", "followsMouseMaxScrollPercent"])
        }
    }

    func testRelativeWorkspaceEdgeBehaviorIsOptionalAndRoundTrips() throws {
        XCTAssertEqual(SettingsExport.defaults().focus.relativeWorkspaceEdgeBehavior, .cycle)
        for behavior in WorkspaceSwipeEdgeBehavior.allCases {
            var export = SettingsExport.defaults()
            export.focus.relativeWorkspaceEdgeBehavior = behavior
            let data = try SettingsTOMLCodec.encode(export)
            let result = try SettingsTOMLCodec.decodeForLoad(data)
            XCTAssertEqual(result.export, export)
            XCTAssertNil(result.migration)
            XCTAssertTrue(SettingsTOMLCodec.unknownKeyPaths(in: data).isEmpty)
        }

        let source = String(decoding: try SettingsTOMLCodec.encode(.defaults()), as: UTF8.self)
        let missing = try removing(key: "relativeWorkspaceEdgeBehavior", from: "focus", in: source)
        let result = try SettingsTOMLCodec.decodeForLoad(Data(missing.utf8))
        XCTAssertEqual(result.export.focus.relativeWorkspaceEdgeBehavior, .cycle)
        XCTAssertNil(result.migration)
        XCTAssertNil(result.migratedData)

        let malformed = source.replacingOccurrences(
            of: "relativeWorkspaceEdgeBehavior = \"cycle\"",
            with: "relativeWorkspaceEdgeBehavior = \"sideways\""
        )
        XCTAssertThrowsError(try SettingsTOMLCodec.decode(Data(malformed.utf8)))
    }

    func testDimUnfocusedSettingsAreOptionalClampedAndRoundTrip() throws {
        let defaults = SettingsExport.defaults().focus
        XCTAssertFalse(defaults.dimUnfocused)
        XCTAssertEqual(defaults.dimUnfocusedOpacity, 0.6)
        var export = SettingsExport.defaults()
        export.focus.dimUnfocused = true
        export.focus.dimUnfocusedOpacity = 0.8
        let data = try SettingsTOMLCodec.encode(export)
        let result = try SettingsTOMLCodec.decodeForLoad(data)
        XCTAssertEqual(result.export, export)
        XCTAssertNil(result.migration)
        XCTAssertTrue(SettingsTOMLCodec.unknownKeyPaths(in: data).isEmpty)

        let source = String(decoding: try SettingsTOMLCodec.encode(.defaults()), as: UTF8.self)
        var missing = try removing(key: "dimUnfocused", from: "focus", in: source)
        missing = try removing(key: "dimUnfocusedOpacity", from: "focus", in: missing)
        let loaded = try SettingsTOMLCodec.decodeForLoad(Data(missing.utf8))
        XCTAssertFalse(loaded.export.focus.dimUnfocused)
        XCTAssertEqual(loaded.export.focus.dimUnfocusedOpacity, 0.6)
        XCTAssertNil(loaded.migration)
        XCTAssertNil(loaded.migratedData)

        let tooDark = source.replacingOccurrences(of: "dimUnfocusedOpacity = 0.6", with: "dimUnfocusedOpacity = 1.5")
        XCTAssertEqual(try SettingsTOMLCodec.decodeForLoad(Data(tooDark.utf8)).export.focus.dimUnfocusedOpacity, 0.95)
        XCTAssertEqual(FocusSettings.normalizedDimUnfocusedOpacity(0), 0.1)
        XCTAssertEqual(FocusSettings.normalizedDimUnfocusedOpacity(.nan), 0.6)
    }

    func testExistingSectionFieldsRemainRequired() throws {
        let data = try SettingsTOMLCodec.encode(.defaults())
        let source = String(decoding: data, as: UTF8.self)
        let sections = [
            "focus": [
                "followsMouse", "raiseOnMouseFocus", "lockModifier", "moveMouseToFocusedWindow",
                "followsWindowToMonitor", "crossesMonitorAtEdge", "moveCrossesMonitorAtEdge"
            ],
            "mouseWarp": ["margin", "enabled", "constrainToArrangement"],
            "routing": ["mode", "arrangements"]
        ]
        for (section, keys) in sections {
            for key in keys {
                let incomplete = try removing(key: key, from: section, in: source)
                XCTAssertThrowsError(try SettingsTOMLCodec.decode(Data(incomplete.utf8))) { error in
                    guard case let DecodingError.keyNotFound(missingKey, context) = error else {
                        return XCTFail("Expected missing section field, got \(error)")
                    }
                    XCTAssertEqual(missingKey.stringValue, key)
                    XCTAssertEqual(context.codingPath.map(\.stringValue), [section])
                }
            }
        }
    }

    private func removing(key: String, from section: String, in source: String) throws -> String {
        var lines = source.components(separatedBy: "\n")
        let header = try XCTUnwrap(lines.firstIndex(of: "[\(section)]"))
        let following = lines.indices.dropFirst(header + 1)
        let sectionEnd = following.first { lines[$0].hasPrefix("[") } ?? lines.endIndex
        let field = try XCTUnwrap(((header + 1) ..< sectionEnd).first {
            lines[$0].hasPrefix("\(key) = ")
        })
        lines.remove(at: field)
        return lines.joined(separator: "\n")
    }
}
