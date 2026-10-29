// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import CoreGraphics
@testable import OmniWM
import XCTest

@MainActor
final class OverviewFitWorkspaceRowsTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)

    func testRowCountFitsTheWorkspacesBetweenTwoAndTheMaximum() {
        let fitted = [0, 1, 2, 3, 4, 9].map { OverviewLayoutCalculator.fittedRowCount(workspaceCount: $0, maxRows: 4) }
        XCTAssertEqual(fitted, [2, 2, 2, 3, 4, 4])
        XCTAssertEqual(OverviewLayoutCalculator.fittedRowCount(workspaceCount: 5, maxRows: 1), 2)
    }

    func testFittedRowsAllFitOnScreenAndShrinkOnlyUpToTheMaximum() {
        for count in 1 ... 6 {
            let sections = layout(workspaces: count, fit: 4).workspaceSections
            let rows = OverviewLayoutCalculator.fittedRowCount(workspaceCount: count, maxRows: 4)
            XCTAssertEqual(sections.count, count)
            let lastVisible = sections[min(rows, count) - 1].visibleFrame
            XCTAssertGreaterThanOrEqual(lastVisible.minY, screen.minY - 0.5, "\(count) workspaces all fit up to \(rows)")
            if count > rows {
                XCTAssertLessThan(sections[rows].visibleFrame.minY, screen.minY, "row \(rows + 1) is off screen")
            }
        }
        let heights = (1 ... 6).map { layout(workspaces: $0, fit: 4).workspaceSections[0].visibleFrame.height }
        XCTAssertEqual(heights[0], heights[1], accuracy: 0.01)
        XCTAssertGreaterThan(heights[1], heights[2])
        XCTAssertGreaterThan(heights[2], heights[3])
        XCTAssertEqual(heights[3], heights[5], accuracy: 0.01)
    }

    func testZoomStillScalesFittedRowsAndUnsetKeepsTheFixedSize() {
        let fitted = layout(workspaces: 4, fit: 4).workspaceSections[0].visibleFrame.height
        let zoomedOut = layout(workspaces: 4, fit: 4, zoom: 0.5).workspaceSections[0].visibleFrame.height
        XCTAssertLessThan(zoomedOut, fitted)

        let fixedTwo = layout(workspaces: 2, fit: nil).workspaceSections[0].visibleFrame.height
        let fixedSix = layout(workspaces: 6, fit: nil).workspaceSections[0].visibleFrame.height
        XCTAssertEqual(fixedTwo, fixedSix, accuracy: 0.01)
        XCTAssertGreaterThan(fixedTwo, fitted)
    }

    func testSettingIsOptionalClampedAndRoundTrips() throws {
        XCTAssertNil(SettingsExport.defaults().overview.fitWorkspaceRows)
        XCTAssertEqual(OverviewSettings.validatedFitWorkspaceRows(1), 2)
        XCTAssertEqual(OverviewSettings.validatedFitWorkspaceRows(4), 4)
        XCTAssertEqual(OverviewSettings.validatedFitWorkspaceRows(10), 6)
        XCTAssertNil(OverviewSettings.validatedFitWorkspaceRows(nil))

        var export = SettingsExport.defaults()
        export.overview.fitWorkspaceRows = 4
        let data = try SettingsTOMLCodec.encode(export)
        let result = try SettingsTOMLCodec.decodeForLoad(data)
        XCTAssertEqual(result.export.overview.fitWorkspaceRows, 4)
        XCTAssertNil(result.migration)
        XCTAssertTrue(SettingsTOMLCodec.unknownKeyPaths(in: data).isEmpty)
        let defaults = String(decoding: try SettingsTOMLCodec.encode(.defaults()), as: UTF8.self)
        XCTAssertFalse(defaults.contains("fitWorkspaceRows"))
    }

    private func layout(workspaces count: Int, fit: Int?, zoom: CGFloat = 1) -> OverviewLayout {
        let workspaces = (1 ... count).map {
            OverviewWorkspaceLayoutItem(id: WorkspaceDescriptor.ID(), name: String($0), isActive: $0 == 1)
        }
        return OverviewLayoutCalculator(screenFrame: screen, scale: zoom, fitWorkspaceRows: fit)
            .calculateLayout(workspaces: workspaces, windows: [:], searchQuery: "")
    }
}
