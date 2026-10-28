// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import CoreGraphics
import Foundation
@testable import OmniWM
import OmniWMIPC
import XCTest

@MainActor
final class MonitorDefaultOrientationTests: XCTestCase {
    private let landscape = makeMonitor(47_610, "Landscape", width: 1920, height: 1080)
    private let portrait = makeMonitor(47_611, "Portrait", width: 1080, height: 1920)

    func testOverrideWinsThenGlobalDefaultThenAspectRatio() {
        let settings = MonitorConfigurationSettings()
        XCTAssertEqual(settings.defaultOrientation, .auto)
        XCTAssertEqual(settings.effectiveOrientation(for: landscape), .horizontal)
        XCTAssertEqual(settings.effectiveOrientation(for: portrait), .vertical)

        for mode in [MonitorOrientationMode.horizontal, .vertical] {
            settings.defaultOrientation = mode
            XCTAssertEqual(settings.effectiveOrientation(for: landscape), mode.fixedOrientation)
            XCTAssertEqual(settings.effectiveOrientation(for: portrait), mode.fixedOrientation)
        }

        settings.updateOrientationSettings(
            MonitorOrientationSettings(monitorName: portrait.name, orientation: .horizontal),
            for: portrait
        )
        for mode in MonitorOrientationMode.allCases {
            settings.defaultOrientation = mode
            XCTAssertEqual(settings.effectiveOrientation(for: portrait), .horizontal)
            XCTAssertEqual(settings.effectiveOrientation(for: landscape), mode.fixedOrientation ?? .horizontal)
        }

        let emptyOverride = MonitorOrientationSettings(monitorName: portrait.name, monitorDisplayId: portrait.displayId)
        for mode in MonitorOrientationMode.allCases {
            XCTAssertEqual(
                MonitorOrientationSettings.effectiveOrientation(
                    for: portrait,
                    overrides: [emptyOverride],
                    defaultOrientation: mode
                ),
                mode.fixedOrientation ?? .vertical
            )
        }
    }

    func testNiriEngineAndDisplaysQueryUseTheResolvedOrientation() throws {
        let controller = WindowAdmissionTestSupport.controller(prefix: "OmniWMMonitorDefaultOrientationTests")
        controller.settings.monitors.defaultOrientation = .horizontal
        controller.workspaceManager.applyMonitorConfigurationChange([portrait])
        controller.niriLayoutHandler.enableNiriLayout()
        let engine = try XCTUnwrap(controller.niriEngine)
        let router = IPCQueryRouter(controller: controller, appVersion: nil, sessionToken: "orientation")
        func reported() throws -> IPCDisplayOrientation? {
            try XCTUnwrap(
                router.displaysResult(IPCQueryRequest(name: .displays, fields: ["orientation"])).displays.first
            ).orientation
        }

        XCTAssertEqual(engine.monitor(for: portrait.id)?.orientation, .horizontal)
        XCTAssertEqual(try reported(), .horizontal)

        controller.settings.monitors.defaultOrientation = .auto
        controller.updateMonitorOrientations()
        XCTAssertEqual(engine.monitor(for: portrait.id)?.orientation, .vertical)
        XCTAssertEqual(try reported(), .vertical)

        controller.settings.monitors.defaultOrientation = .horizontal
        controller.settings.monitors.updateOrientationSettings(
            MonitorOrientationSettings(monitorName: portrait.name, orientation: .vertical),
            for: portrait
        )
        controller.updateMonitorOrientations()
        XCTAssertEqual(engine.monitor(for: portrait.id)?.orientation, .vertical)
        XCTAssertEqual(try reported(), .vertical)
    }

    func testDefaultOrientationIsOmittedFromCanonicalTOMLWhenAuto() throws {
        let defaults = String(decoding: try SettingsTOMLCodec.encode(.defaults()), as: UTF8.self)
        XCTAssertFalse(defaults.contains("[monitors]"))
        XCTAssertFalse(defaults.contains("defaultOrientation"))

        let result = try SettingsTOMLCodec.decodeForLoad(Data(defaults.utf8))
        XCTAssertEqual(SettingsExport.defaults().defaultMonitorOrientation, .auto)
        XCTAssertEqual(result.export.defaultMonitorOrientation, .auto)
        XCTAssertNil(result.migration)
    }

    func testDefaultOrientationRoundTripsWithAndWithoutRanking() throws {
        for ranking in [[], [OutputId(name: "Built-in Retina Display")]] {
            for mode in MonitorOrientationMode.allCases {
                var export = SettingsExport.defaults()
                export.monitorRanking = ranking
                export.defaultMonitorOrientation = mode
                let data = try SettingsTOMLCodec.encode(export)
                let toml = String(decoding: data, as: UTF8.self)

                let result = try SettingsTOMLCodec.decodeForLoad(data)
                XCTAssertEqual(result.export, export)
                XCTAssertNil(result.migration)
                XCTAssertTrue(SettingsTOMLCodec.unknownKeyPaths(in: data).isEmpty)
                XCTAssertEqual(
                    toml.contains("defaultOrientation = \"\(mode.rawValue)\""),
                    !(ranking.isEmpty && mode == .auto),
                    toml
                )
            }
        }
    }

    func testHandWrittenMonitorsTableNeedsNoRankingAndRejectsUnknownValues() throws {
        let canonical = String(decoding: try SettingsTOMLCodec.encode(.defaults()), as: UTF8.self)
        func withMonitorsTable(_ value: String) -> Data {
            Data((canonical + "\n[monitors]\ndefaultOrientation = \(value)\n").utf8)
        }

        for mode in [MonitorOrientationMode.horizontal, .vertical] {
            let data = withMonitorsTable("\"\(mode.rawValue)\"")
            let result = try SettingsTOMLCodec.decodeForLoad(data)
            XCTAssertEqual(result.export.defaultMonitorOrientation, mode)
            XCTAssertEqual(result.export.monitorRanking, [])
            XCTAssertNil(result.migration)
            XCTAssertTrue(SettingsTOMLCodec.unknownKeyPaths(in: data).isEmpty)
        }
        XCTAssertEqual(try SettingsTOMLCodec.decode(withMonitorsTable("\"auto\"")).defaultMonitorOrientation, .auto)
        for value in ["\"portrait\"", "\"Horizontal\"", "true"] {
            XCTAssertThrowsError(try SettingsTOMLCodec.decode(withMonitorsTable(value)), value)
        }
    }

    func testSettingsStoreAppliesAndExportsTheDefault() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = SettingsStore(
            persistence: SettingsFilePersistence(directory: directory, startWatching: false, deferSaves: false),
            runtimeState: RuntimeStateStore(directory: directory, deferSaves: false),
            autosaveEnabled: false
        )
        XCTAssertEqual(settings.monitors.defaultOrientation, .auto)
        var export = settings.toExport()
        XCTAssertEqual(export.defaultMonitorOrientation, .auto)

        export.defaultMonitorOrientation = .horizontal
        settings.applyExport(export)

        XCTAssertEqual(settings.monitors.defaultOrientation, .horizontal)
        XCTAssertEqual(settings.toExport().defaultMonitorOrientation, .horizontal)
        XCTAssertEqual(settings.monitors.effectiveOrientation(for: portrait), .horizontal)
    }
}

private func makeMonitor(
    _ displayId: CGDirectDisplayID,
    _ name: String,
    width: CGFloat,
    height: CGFloat
) -> Monitor {
    let frame = CGRect(x: 0, y: 0, width: width, height: height)
    return Monitor(
        id: .init(displayId: displayId),
        displayId: displayId,
        frame: frame,
        visibleFrame: frame,
        hasNotch: false,
        name: name
    )
}
