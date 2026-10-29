// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation
@testable import OmniWMCtl
import OmniWMIPC
import XCTest

final class WorkspaceRelativeIPCCommandTests: XCTestCase {
    private static let cases: [(request: IPCCommandRequest, name: IPCCommandName, rawName: String, words: [String])] = [
        (.workspace(.switchToNew), .workspace(.switchToNew), "switch-workspace-new", ["switch-workspace", "new"]),
        (.workspace(.moveToNew), .workspace(.moveToNew), "move-to-workspace-new", ["move-to-workspace", "new"]),
        (.workspace(.moveNext), .workspace(.moveNext), "move-to-workspace-next", ["move-to-workspace", "next"]),
        (
            .workspace(.movePrevious),
            .workspace(.movePrevious),
            "move-to-workspace-previous",
            ["move-to-workspace", "prev"]
        )
    ]

    func testRequestsRoundTripThroughJSONAndManifest() throws {
        for entry in Self.cases {
            XCTAssertEqual(entry.request.name, entry.name)
            XCTAssertEqual(entry.name.rawValue, entry.rawName)
            XCTAssertEqual(IPCCommandName(rawValue: entry.rawName), entry.name)

            let data = try JSONEncoder().encode(entry.request)
            XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"name":"\#(entry.rawName)"}"#)
            XCTAssertEqual(try JSONDecoder().decode(IPCCommandRequest.self, from: data), entry.request)

            let descriptor = try XCTUnwrap(IPCAutomationManifest.commandDescriptor(for: entry.name))
            XCTAssertEqual(descriptor.commandWords, entry.words)
            XCTAssertTrue(descriptor.arguments.isEmpty)
            XCTAssertEqual(descriptor.layoutCompatibility, .shared)
            XCTAssertEqual(try IPCCommandRequest(name: entry.name), entry.request)
            XCTAssertThrowsError(try IPCCommandRequest(name: entry.name, argumentValues: [.integer(1)]))
        }
    }

    func testParserBuildsRequestsAndKeepsNumericAndDirectionalForms() throws {
        for entry in Self.cases {
            XCTAssertEqual(try commandPayload(entry.words), entry.request, entry.words.joined(separator: " "))
        }
        XCTAssertEqual(try commandPayload(["switch-workspace", "next"]), .workspace(.next))
        XCTAssertEqual(try commandPayload(["switch-workspace", "prev"]), .workspace(.previous))
        XCTAssertEqual(try commandPayload(["switch-workspace", "4"]), .workspace(.switchTo(workspaceNumber: 4)))
        XCTAssertEqual(try commandPayload(["move-to-workspace", "up"]), .workspace(.moveUp))
        XCTAssertEqual(try commandPayload(["move-to-workspace", "down"]), .workspace(.moveDown))
        XCTAssertEqual(try commandPayload(["move-to-workspace", "4"]), .workspace(.moveTo(workspaceNumber: 4)))

        for malformed in [
            ["switch-workspace", "new", "2"],
            ["move-to-workspace", "new", "2"],
            ["move-to-workspace", "next", "2"],
            ["move-to-workspace", "previous"]
        ] {
            XCTAssertThrowsError(try commandPayload(malformed), malformed.joined(separator: " "))
        }
    }

    func testHelpAndCompletionsExposeCommands() {
        for entry in Self.cases {
            XCTAssertTrue(CLIParser.usageText.contains("omniwmctl command \(entry.words.joined(separator: " "))\n"))
            let suggestions = CLICompletionCatalog.commandSlotThreeSuggestionsByFirst[entry.words[0]] ?? []
            XCTAssertTrue(suggestions.contains(entry.words[1]), entry.words.joined(separator: " "))
        }
        for shell in CLIShell.allCases {
            let script = CLICompletionGenerator.script(for: shell)
            XCTAssertTrue(script.contains("new"), shell.rawValue)
            XCTAssertTrue(script.contains("prev"), shell.rawValue)
        }
    }

    private func commandPayload(_ words: [String]) throws -> IPCCommandRequest {
        let parsed = try CLIParser.parse(arguments: ["omniwmctl", "command"] + words)
        guard case let .command(request) = parsed.request.payload else {
            throw CLIParseError.usage("expected a command payload")
        }
        return request
    }
}
