// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation
@testable import OmniWM
import OmniWMIPC
import XCTest

@MainActor
final class SettingsIPCTests: XCTestCase {
    // MARK: Catalog

    func testCatalogCoversEveryScalarSettingExceptTheLeftOutOnes() throws {
        let tree = try SettingsTOMLCodec.canonicalTree(SettingsStore.defaultExport)
        let catalogKeys = Set(IPCSettingsCatalog.sections.flatMap(\.entries).map(\.key))
        let missing = scalarKeys(in: tree).filter {
            !catalogKeys.contains($0) && !IPCSettingsCatalog.notSettableKeys.contains($0)
        }
        XCTAssertEqual(missing, [], "scalar settings missing from IPCSettingsCatalog")
    }

    func testCatalogKeysAreUniqueAndMatchTheirSectionAndTOMLType() throws {
        let tree = try SettingsTOMLCodec.canonicalTree(SettingsStore.defaultExport)
        var seen: Set<String> = []
        for section in IPCSettingsCatalog.sections {
            for entry in section.entries {
                XCTAssertTrue(seen.insert(entry.key).inserted, "duplicate \(entry.key)")
                XCTAssertTrue(entry.key.hasPrefix(section.id + "."), "\(entry.key) isn't in \(section.id)")
                XCTAssertFalse(entry.title.isEmpty, entry.key)
                XCTAssertFalse(entry.description.isEmpty, entry.key)
                XCTAssertFalse(IPCSettingsCatalog.notSettableKeys.contains(entry.key), entry.key)
                guard let node = IPCSettingsCatalog.effectiveNode(at: IPCSettingsCatalog.path(of: entry.key), in: tree)
                else { continue }
                switch (entry.kind, node) {
                case (.bool, .boolean),
                     (.int, .integer),
                     (.number, .float),
                     (.choice, .string),
                     (.string, .string):
                    break
                default:
                    XCTFail("\(entry.key): catalog kind \(entry.kind) doesn't match TOML \(node)")
                }
            }
        }
    }

    func testEveryChoiceAndRangeEndIsAcceptedByTheSettingsDecoder() {
        let export = SettingsStore.defaultExport
        for entry in IPCSettingsCatalog.sections.flatMap(\.entries) {
            var values: [String] = []
            switch entry.kind {
            case let .choice(choices):
                values = choices.map(\.value)
                XCTAssertEqual(Set(values).count, values.count, entry.key)
            case let .int(min, max, _):
                values = [min, max].compactMap { $0 }.map(String.init)
            case let .number(min, max, _):
                values = [min, max].compactMap { $0 }.map { String($0) }
            case .bool,
                 .string:
                continue
            }
            for value in values {
                if case let .failure(failure) = IPCSettingsCatalog.change(
                    .set(key: entry.key, value: value),
                    in: export
                ) {
                    XCTFail("\(entry.key) = \(value) rejected: \(failure.detail)")
                }
            }
        }
    }

    // MARK: Query

    func testQueryListsScalarsOnlyInCatalogOrder() {
        let controller = makeController()
        let settings = IPCQueryRouter(controller: controller, sessionToken: "test").settingsResult().settings
        let keys = settings.map(\.key)

        XCTAssertEqual(keys, IPCSettingsCatalog.sections.flatMap(\.entries).map(\.key))
        for leftOut in [
            "general.ipcEnabled", "schemaVersion", "hotkeys", "workspaces", "appRules", "borders.color",
            "overview.backdrop", "overview.windowBorders.selected", "niri.containerPrimarySpanPresets",
            "routing.arrangements", "monitorOrientationOverrides"
        ] {
            XCTAssertFalse(keys.contains { $0 == leftOut || $0.hasPrefix(leftOut + ".") }, leftOut)
        }
        XCTAssertFalse(keys.contains { [".red", ".green", ".blue", ".alpha"].contains(where: $0.hasSuffix) })

        let dim = try? XCTUnwrap(settings.first { $0.key == "focus.dimUnfocused" })
        XCTAssertEqual(dim?.type, .bool)
        XCTAssertEqual(dim?.value, .bool(false))
        XCTAssertEqual(dim?.defaultValue, .bool(false))
        XCTAssertEqual(dim?.section, "focus")
        XCTAssertEqual(dim?.sectionTitle, "Focus")

        let edge = settings.first { $0.key == "focus.relativeWorkspaceEdgeBehavior" }
        XCTAssertEqual(edge?.type, .enumeration)
        XCTAssertEqual(edge?.choices?.map(\.value), ["cycle", "none", "onePast"])
        XCTAssertEqual(edge?.value, .string("cycle"))

        let opacity = settings.first { $0.key == "focus.dimUnfocusedOpacity" }
        XCTAssertEqual(opacity?.type, .number)
        XCTAssertEqual(opacity?.value, .number(0.6))
        XCTAssertEqual(opacity?.min, 0.1)
        XCTAssertEqual(opacity?.max, 0.95)

        let unlimited = settings.first { $0.key == "focus.followsMouseMaxScrollPercent" }
        XCTAssertEqual(unlimited?.type, .int)
        XCTAssertEqual(unlimited?.value, .null)
    }

    func testQueryKeySelectorReturnsOneSettingOrTypedFailure() async throws {
        let controller = makeController()
        let bridge = makeBridge(controller)

        let one = await bridge.response(for: query(key: "focus.dimUnfocusedOpacity"))
        XCTAssertTrue(one.ok)
        guard case let .settings(payload)? = one.result?.payload else { return XCTFail("\(one)") }
        XCTAssertEqual(payload.settings.map(\.key), ["focus.dimUnfocusedOpacity"])

        let unknown = await bridge.response(for: query(key: "focus.nope"))
        XCTAssertEqual(unknown.code, .unknownSetting)
        XCTAssertNotNil(unknown.detail)

        let leftOut = await bridge.response(for: query(key: "general.ipcEnabled"))
        XCTAssertEqual(leftOut.code, .notSettable)
        XCTAssertNotNil(leftOut.detail)
    }

    func testQueryAndChangesWorkWhileDisabled() async {
        let controller = makeController()
        controller.setEnabled(false)
        XCTAssertFalse(controller.isEnabled)
        let bridge = makeBridge(controller)

        let query = await bridge.response(for: query(key: nil))
        XCTAssertTrue(query.ok)
        let set = await bridge.response(for: IPCRequest(
            id: "set",
            settings: .set(key: "focus.dimUnfocused", value: "true"),
            authorizationToken: "auth"
        ))
        XCTAssertTrue(set.ok, "\(set)")
        XCTAssertEqual(set.kind, .settings)
        XCTAssertTrue(controller.settings.focus.dimUnfocused)
    }

    // MARK: Changes

    func testSetAppliesLiveAndReportsValueAndPrevious() {
        let controller = makeController()
        let change = perform(controller, .set(key: "focus.dimUnfocusedOpacity", value: "0.8"))

        XCTAssertEqual(change?.key, "focus.dimUnfocusedOpacity")
        XCTAssertEqual(change?.value, .number(0.8))
        XCTAssertEqual(change?.previous, .number(0.6))
        XCTAssertEqual(controller.settings.focus.dimUnfocusedOpacity, 0.8)

        let enumChange = perform(controller, .set(key: "focus.relativeWorkspaceEdgeBehavior", value: "onePast"))
        XCTAssertEqual(enumChange?.value, .string("onePast"))
        XCTAssertEqual(enumChange?.previous, .string("cycle"))
        XCTAssertEqual(controller.settings.focus.relativeWorkspaceEdgeBehavior, .onePast)
    }

    func testSetReportsTheValueInEffectAfterRounding() {
        let controller = makeController()
        let change = perform(controller, .set(key: "focus.edgeNavigationInterval", value: "1.3"))
        XCTAssertEqual(change?.value, .number(1.25))
    }

    func testSettingTheCurrentValueSucceedsWithoutAChange() {
        let controller = makeController()
        var changes = 0
        controller.settings.onSettingsChanged = { changes += 1 }

        let change = perform(controller, .set(key: "focus.dimUnfocused", value: "false"))
        XCTAssertEqual(change?.value, .bool(false))
        XCTAssertEqual(change?.previous, .bool(false))

        let reset = perform(controller, .reset(key: "focus.dimUnfocusedOpacity"))
        XCTAssertEqual(reset?.value, reset?.previous)
        XCTAssertEqual(changes, 0)
    }

    func testToggleAndReset() {
        let controller = makeController()
        XCTAssertEqual(perform(controller, .toggle(key: "focus.dimUnfocused"))?.value, .bool(true))
        XCTAssertTrue(controller.settings.focus.dimUnfocused)
        XCTAssertEqual(perform(controller, .toggle(key: "focus.dimUnfocused"))?.value, .bool(false))

        _ = perform(controller, .set(key: "focus.dimUnfocusedOpacity", value: "0.3"))
        let reset = perform(controller, .reset(key: "focus.dimUnfocusedOpacity"))
        XCTAssertEqual(reset?.value, .number(0.6))
        XCTAssertEqual(reset?.previous, .number(0.3))

        _ = perform(controller, .set(key: "focus.followsMouseMaxScrollPercent", value: "40"))
        XCTAssertEqual(perform(controller, .reset(key: "focus.followsMouseMaxScrollPercent"))?.value, .null)
    }

    func testSettingAKeyInAMissingOptionalTableCreatesTheTable() {
        let controller = makeController()
        XCTAssertNil(controller.settings.toExport().borders.glow)
        let glow = perform(controller, .set(key: "borders.glow.enabled", value: "true"))
        XCTAssertEqual(glow?.previous, .bool(false))
        XCTAssertEqual(glow?.value, .bool(true))
        XCTAssertEqual(controller.settings.toExport().borders.glow?.radius, BorderGlow.default.radius)

        let placement = perform(controller, .set(key: "quakeTerminal.kitty.placement.widthPercent", value: "80"))
        XCTAssertEqual(placement?.value, .number(80))
        XCTAssertEqual(
            controller.settings.toExport().quakeTerminal.kitty?.placement?.heightPercent,
            KittyQuakeSettings.Placement.defaultOverride.heightPercent
        )
    }

    func testFailuresCarryCodeAndDetail() {
        let controller = makeController()
        let cases: [(IPCSettingsRequest, IPCErrorCode, String?)] = [
            (.set(key: "focus.dimUnfocusedOpacity", value: "2"), .invalidValue, "must be between 0.1 and 0.95"),
            (.set(key: "focus.dimUnfocusedOpacity", value: "dark"), .invalidValue, "must be a number"),
            (.set(key: "focus.dimUnfocused", value: "yes"), .invalidValue, "must be true or false"),
            (
                .set(key: "focus.relativeWorkspaceEdgeBehavior", value: "sideways"),
                .invalidValue,
                "must be one of cycle, none, onePast"
            ),
            (.toggle(key: "focus.dimUnfocusedOpacity"), .invalidValue, nil),
            (.set(key: "focus.nope", value: "1"), .unknownSetting, nil),
            (.set(key: "general.ipcEnabled", value: "false"), .notSettable, nil),
            (.toggle(key: "general.ipcEnabled"), .notSettable, nil),
            (.set(key: "borders.color", value: "red"), .notSettable, nil),
            (.reset(key: "hotkeys"), .notSettable, nil)
        ]
        let executor = IPCSettingsRequestExecutor(controller: controller)
        for (request, code, detail) in cases {
            let response = executor.response(for: request, id: "1")
            XCTAssertFalse(response.ok, "\(request)")
            XCTAssertEqual(response.code, code, "\(request)")
            XCTAssertFalse(response.detail?.isEmpty ?? true, "\(request)")
            if let detail {
                XCTAssertEqual(response.detail, detail)
            }
        }
        XCTAssertEqual(controller.settings.focus.dimUnfocusedOpacity, 0.6)
        XCTAssertTrue(controller.settings.ipcEnabled == SettingsStore.defaultExport.ipcEnabled)
    }

    func testCrossSettingValidationRejectsConflictingGestures() {
        let controller = makeController()
        _ = perform(controller, .set(key: "gestures.scrollEnabled", value: "true"))
        let fingers = controller.settings.toExport().gestures.fingerCount.rawValue
        let moveFingers = fingers == 4 ? "3" : "4"
        _ = perform(controller, .set(key: "gestures.windowMoveFingerCount", value: moveFingers))
        _ = perform(controller, .set(key: "gestures.windowMoveEnabled", value: "true"))

        let response = IPCSettingsRequestExecutor(controller: controller).response(
            for: .set(key: "gestures.windowMoveFingerCount", value: String(fingers)),
            id: "1"
        )
        XCTAssertEqual(response.code, .invalidValue)
        XCTAssertNotNil(response.detail)
        XCTAssertEqual(controller.settings.toExport().gestures.windowMoveFingerCount?.rawValue, Int(moveFingers))
    }

    func testChangesAreSavedToSettingsTOML() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("OmniWMSettingsIPC-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let persistence = SettingsFilePersistence(
            directory: root.appendingPathComponent("config"),
            startWatching: false,
            deferSaves: false
        )
        let controller = makeController(persistence: persistence, root: root, autosave: true)

        _ = perform(controller, .set(key: "focus.dimUnfocusedOpacity", value: "0.75"))
        _ = perform(controller, .set(key: "focus.relativeWorkspaceEdgeBehavior", value: "none"))

        let saved = try SettingsTOMLCodec.decode(Data(contentsOf: persistence.fileURL))
        XCTAssertEqual(saved.focus.dimUnfocusedOpacity, 0.75)
        XCTAssertEqual(saved.focus.relativeWorkspaceEdgeBehavior, WorkspaceSwipeEdgeBehavior.none)
    }

    // MARK: settings-changed

    func testSettingsChangedEventCarriesAFullSnapshotAfterAnIPCSet() async throws {
        let controller = makeController()
        let bridge = makeBridge(controller)
        controller.ipcApplicationBridge = bridge
        let registration = await bridge.registerStream(for: .settingsChanged)

        _ = perform(controller, .set(key: "focus.dimUnfocusedOpacity", value: "0.5"))

        let event = try await nextEvent(registration.stream)
        XCTAssertEqual(event.channel, .settingsChanged)
        guard case let .settings(payload) = event.result.payload else { return XCTFail("\(event)") }
        XCTAssertEqual(payload.settings.count, IPCSettingsCatalog.sections.flatMap(\.entries).count)
        XCTAssertEqual(payload.settings.first { $0.key == "focus.dimUnfocusedOpacity" }?.value, .number(0.5))
        await bridge.unregisterStream(registration)
    }

    func testSettingsChangedFiresForSettingsWindowChangesAndHotkeyEdits() async throws {
        let controller = makeController()
        let bridge = makeBridge(controller)
        controller.ipcApplicationBridge = bridge
        let registration = await bridge.registerStream(for: .settingsChanged)

        controller.settings.focus.dimUnfocused = true
        let windowEvent = try await nextEvent(registration.stream)
        guard case let .settings(payload) = windowEvent.result.payload else { return XCTFail("\(windowEvent)") }
        XCTAssertEqual(payload.settings.first { $0.key == "focus.dimUnfocused" }?.value, .bool(true))

        var bindings = controller.settings.hotkeyBindings
        let index = try XCTUnwrap(bindings.firstIndex { !$0.binding.isUnassigned })
        bindings[index].binding = .unassigned
        controller.settings.hotkeyBindings = bindings
        let hotkeyEvent = try await nextEvent(registration.stream)
        XCTAssertEqual(hotkeyEvent.channel, .settingsChanged)
        await bridge.unregisterStream(registration)
    }

    func testSettingsChangedFiresWhenAnEditedFileIsReloaded() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("OmniWMSettingsReload-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let persistence = SettingsFilePersistence(
            directory: root.appendingPathComponent("config"),
            startWatching: false,
            deferSaves: false
        )
        let settings = SettingsStore(
            persistence: persistence,
            runtimeState: RuntimeStateStore(directory: root.appendingPathComponent("state"), deferSaves: false),
            autosaveEnabled: true
        )
        try settings.ensureSettingsFileAvailable()
        var changes = 0
        settings.onSettingsChanged = { changes += 1 }

        var export = settings.toExport()
        export.focus.dimUnfocused = true
        try SettingsTOMLCodec.encode(export).write(to: persistence.fileURL)
        persistence.handlePossibleSettingsFileChange()

        XCTAssertTrue(settings.focus.dimUnfocused)
        XCTAssertEqual(changes, 1)
    }

    // MARK: Wire

    func testWireShapes() throws {
        let failure = IPCResponse.failure(
            id: "1",
            kind: .settings,
            code: .invalidValue,
            detail: "must be true or false"
        )
        let failureJSON = try jsonObject(IPCWire.encodeResponseLine(failure))
        XCTAssertEqual(failureJSON["code"] as? String, "invalid_value")
        XCTAssertEqual(failureJSON["detail"] as? String, "must be true or false")
        XCTAssertEqual(try IPCWire.decodeResponse(from: IPCWire.encodeResponseLine(failure)), failure)

        let descriptor = IPCSettingDescriptor(
            key: "focus.followsMouseMaxScrollPercent", section: "focus", sectionTitle: "Focus",
            title: "Maximum Mouse Focus Scroll", description: "Limits scrolling.", type: .int,
            value: .null, defaultValue: .null, min: 0, max: 100, step: 5
        )
        let success = IPCResponse.success(
            id: "2",
            kind: .query,
            result: IPCResult(settings: IPCSettingsQueryResult(settings: [descriptor]))
        )
        let json = try jsonObject(IPCWire.encodeResponseLine(success))
        let result = try XCTUnwrap(json["result"] as? [String: Any])
        XCTAssertEqual(result["kind"] as? String, "settings")
        let setting = try XCTUnwrap(((result["payload"] as? [String: Any])?["settings"] as? [[String: Any]])?.first)
        XCTAssertTrue(setting["value"] is NSNull)
        XCTAssertTrue(setting["default"] is NSNull)
        XCTAssertEqual(setting["type"] as? String, "int")
        XCTAssertEqual(setting["max"] as? Int, 100)
        XCTAssertNil(setting["choices"])
        XCTAssertEqual(try IPCWire.decodeResponse(from: IPCWire.encodeResponseLine(success)), success)

        let change = IPCResponse.success(
            id: "3",
            kind: .settings,
            status: .executed,
            result: IPCResult(settingChange: IPCSettingChangeResult(
                key: "focus.dimUnfocused",
                value: .bool(true),
                previous: .bool(false)
            ))
        )
        let changeJSON = try jsonObject(IPCWire.encodeResponseLine(change))
        let changePayload = try XCTUnwrap((changeJSON["result"] as? [String: Any])?["payload"] as? [String: Any])
        XCTAssertEqual(changePayload["value"] as? Bool, true)
        XCTAssertEqual(changePayload["previous"] as? Bool, false)

        for request in [
            IPCSettingsRequest.set(key: "a.b", value: "two words"),
            .toggle(key: "a.b"),
            .reset(key: "a.b")
        ] {
            let line = try IPCWire.encodeRequestLine(IPCRequest(id: "r", settings: request))
            XCTAssertEqual(try IPCWire.decodeRequest(from: line).payload, .settings(request))
        }
    }

    func testSettingsWireMatchesTheJSONEncoderReference() throws {
        let controller = makeController()
        let router = IPCQueryRouter(controller: controller, sessionToken: "test")
        let responses: [IPCResponse] = [
            .success(id: "q", kind: .query, result: IPCResult(settings: router.settingsResult())),
            .success(id: "c", kind: .query, result: IPCResult(commands: router.commandsResult())),
            .success(id: "k", kind: .query, result: IPCResult(capabilities: router.capabilitiesResult())),
            .success(
                id: "s",
                kind: .settings,
                status: .executed,
                result: IPCResult(settingChange: IPCSettingChangeResult(
                    key: "general.language",
                    value: .string("ja"),
                    previous: .null
                ))
            ),
            .failure(id: "f", kind: .settings, code: .notSettable, detail: "general.ipcEnabled can't be changed")
        ]
        for response in responses {
            for pretty in [false, true] {
                let encoder = JSONEncoder()
                encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
                var reference = try encoder.encode(response)
                reference.append(0x0A)
                XCTAssertEqual(
                    String(decoding: try IPCWire.encodeResponseLine(response, prettyPrinted: pretty), as: UTF8.self),
                    String(decoding: reference, as: UTF8.self),
                    response.id
                )
            }
        }
        let event = IPCEventEnvelope.success(
            id: "e",
            channel: .settingsChanged,
            result: IPCResult(settings: router.settingsResult())
        )
        var reference = try JSONEncoder().encodeSorted(event)
        reference.append(0x0A)
        XCTAssertEqual(try IPCWire.encodeEventLine(event), reference)
    }

    // MARK: query commands

    func testCommandArgumentsListTheirChoices() throws {
        let focus = try XCTUnwrap(IPCAutomationManifest.commandDescriptor(for: .focus(.spatial)))
        XCTAssertEqual(focus.arguments.first?.choices, ["left", "right", "up", "down"])
        let switchWorkspace = try XCTUnwrap(IPCAutomationManifest.commandDescriptor(for: .workspace(.switchTo)))
        XCTAssertNil(switchWorkspace.arguments.first?.choices)
    }

    func testCommandsQueryAddsTitlesAndHotkeys() throws {
        let bindings = SettingsStore.defaultExport.hotkeyBindings
        let descriptors = IPCCommandPresentation.commandDescriptors(hotkeyBindings: bindings)
        XCTAssertEqual(descriptors.map(\.path), IPCAutomationManifest.commandDescriptors.map(\.path))
        for descriptor in descriptors {
            XCTAssertFalse(descriptor.title?.isEmpty ?? true, descriptor.path)
            XCTAssertNotNil(descriptor.hotkeys, descriptor.path)
            XCTAssertNotNil(descriptor.argumentHotkeys, descriptor.path)
        }

        let focus = try XCTUnwrap(descriptors.first { $0.name == .focus(.spatial) })
        XCTAssertEqual(focus.title, "Focus")
        XCTAssertEqual(focus.argumentHotkeys?["left"], ["⌥←"])
        XCTAssertEqual(focus.hotkeys, [])

        let titles = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.name.rawValue, $0.title ?? "") })
        XCTAssertEqual(titles["switch-workspace"], "Switch to Workspace")
        XCTAssertEqual(titles["scratchpad-toggle"], "Toggle Scratchpad")
        XCTAssertEqual(titles["scratchpad-assign"], "Toggle Scratchpad Assignment for Focused Window")
        XCTAssertEqual(titles["open-command-palette-mode"], "Command Palette")
        let duplicates = Dictionary(grouping: titles.keys.sorted()) { titles[$0] ?? "" }.filter { $0.value.count > 1 }
        XCTAssertEqual(duplicates, [:])

        let switchWorkspace = try XCTUnwrap(descriptors.first { $0.name == .workspace(.switchTo) })
        XCTAssertEqual(switchWorkspace.argumentHotkeys?["1"], ["⌥1"])
        XCTAssertEqual(switchWorkspace.argumentHotkeys?["9"], ["⌥9"])

        let boundWhole = descriptors.filter { $0.arguments.isEmpty && !($0.hotkeys ?? []).isEmpty }
        XCTAssertFalse(boundWhole.isEmpty)
        for descriptor in boundWhole {
            let spec = ActionCatalog.allSpecs().first { $0.ipcCommandName == descriptor.name }
            XCTAssertEqual(descriptor.title, spec?.localizedTitle, descriptor.path)
        }

        var unbound = bindings
        for index in unbound.indices {
            unbound[index].binding = .unassigned
        }
        let none = IPCCommandPresentation.commandDescriptors(hotkeyBindings: unbound)
        XCTAssertTrue(none.allSatisfy { $0.hotkeys == [] && $0.argumentHotkeys == [:] })
    }

    func testCommandsQueryJSONCarriesTheNewFields() throws {
        let controller = makeController()
        let result = IPCQueryRouter(controller: controller, sessionToken: "test").commandsResult()
        let json = try jsonObject(IPCWire.encodeResponseLine(.success(
            id: "1",
            kind: .query,
            result: IPCResult(commands: result)
        )))
        let payload = try XCTUnwrap((json["result"] as? [String: Any])?["payload"] as? [String: Any])
        let commands = try XCTUnwrap(payload["commands"] as? [[String: Any]])
        let focus = try XCTUnwrap(commands.first { $0["name"] as? String == "focus" })
        XCTAssertEqual(focus["title"] as? String, "Focus")
        XCTAssertNotNil(focus["hotkeys"] as? [String])
        XCTAssertNotNil(focus["argumentHotkeys"] as? [String: [String]])
        let argument = try XCTUnwrap((focus["arguments"] as? [[String: Any]])?.first)
        XCTAssertEqual(argument["choices"] as? [String], ["left", "right", "up", "down"])
        XCTAssertEqual((payload["settingsActions"] as? [[String: Any]])?.count, 3)
    }

    // MARK: Helpers

    private func makeController(
        persistence: SettingsFilePersistence? = nil,
        root: URL? = nil,
        autosave: Bool = false
    ) -> WMController {
        let root = root ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniWMSettingsIPC-\(UUID().uuidString)", isDirectory: true)
        let settings = SettingsStore(
            persistence: persistence ?? SettingsFilePersistence(
                directory: root.appendingPathComponent("config", isDirectory: true),
                startWatching: false,
                deferSaves: false
            ),
            runtimeState: RuntimeStateStore(
                directory: root.appendingPathComponent("state", isDirectory: true),
                deferSaves: false
            ),
            autosaveEnabled: autosave
        )
        return WMController(
            settings: settings,
            windowFocusOperations: WindowFocusOperations(
                activateApp: { _ in },
                focusSpecificWindow: { _, _, _ in },
                raiseWindow: { _ in }
            )
        )
    }

    private func makeBridge(_ controller: WMController) -> IPCApplicationBridge {
        IPCApplicationBridge(
            controller: controller,
            appVersion: "test",
            sessionToken: "session",
            authorizationToken: "auth"
        )
    }

    private func query(key: String?) -> IPCRequest {
        IPCRequest(
            id: "q",
            query: IPCQueryRequest(name: .settings, selectors: IPCQuerySelectors(key: key)),
            authorizationToken: "auth"
        )
    }

    private func perform(_ controller: WMController, _ request: IPCSettingsRequest) -> IPCSettingChangeResult? {
        switch IPCSettingsRequestExecutor(controller: controller).perform(request) {
        case let .success(change):
            return change
        case let .failure(failure):
            XCTFail("\(request) failed: \(failure.code) \(failure.detail)")
            return nil
        }
    }

    private func nextEvent(_ stream: AsyncStream<IPCEventEnvelope>) async throws -> IPCEventEnvelope {
        let event = await withTaskGroup(of: IPCEventEnvelope?.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                return await iterator.next()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(5))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        return try XCTUnwrap(event, "no settings-changed event")
    }

    private func scalarKeys(in tree: [String: TOMLNode], prefix: String = "") -> [String] {
        tree.keys.sorted().flatMap { key -> [String] in
            let path = prefix.isEmpty ? key : "\(prefix).\(key)"
            switch tree[key] {
            case let .table(table)?:
                if Set(table.keys).isSuperset(of: ["red", "green", "blue"]) {
                    return []
                }
                return scalarKeys(in: table, prefix: path)
            case .array?,
                 nil:
                return []
            default:
                return [path]
            }
        }
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private extension JSONEncoder {
    func encodeSorted(_ value: some Encodable) throws -> Data {
        outputFormatting = [.sortedKeys]
        return try encode(value)
    }
}
