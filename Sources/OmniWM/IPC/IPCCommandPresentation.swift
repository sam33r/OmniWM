// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

// Fork: `query commands` gives each command the title the command palette shows
// and the user's hotkeys for it, so launchers can list commands the way OmniWM
// does. A hotkey that binds particular argument values (Option+1 for
// `switch-workspace 1`) is listed under those arguments as typed for omniwmctl.

import Foundation
import OmniWMIPC

@MainActor
enum IPCCommandPresentation {
    static func commandDescriptors(hotkeyBindings: [HotkeyBinding]) -> [IPCCommandDescriptor] {
        var specsByName: [IPCCommandName: [ActionSpec]] = [:]
        for spec in ActionCatalog.allSpecs() {
            if let name = spec.ipcCommandName {
                specsByName[name, default: []].append(spec)
            }
        }
        var hotkeysByName: [IPCCommandName: [String]] = [:]
        var argumentHotkeysByName: [IPCCommandName: [String: [String]]] = [:]
        for binding in hotkeyBindings where !binding.binding.isUnassigned {
            guard let invocation = invocation(for: binding.command) else { continue }
            let display = binding.binding.displayString
            if let arguments = invocation.arguments {
                appendUnique(display, to: &argumentHotkeysByName[invocation.name, default: [:]][arguments, default: []])
            } else {
                appendUnique(display, to: &hotkeysByName[invocation.name, default: []])
            }
        }
        return IPCAutomationManifest.commandDescriptors.map { descriptor in
            descriptor.withPresentation(
                title: title(for: descriptor, specs: specsByName[descriptor.name] ?? []),
                hotkeys: hotkeysByName[descriptor.name] ?? [],
                argumentHotkeys: argumentHotkeysByName[descriptor.name] ?? [:]
            )
        }
    }

    private static func appendUnique(_ value: String, to list: inout [String]) {
        if !list.contains(value) {
            list.append(value)
        }
    }

    /// The IPC command a hotkey runs, and the arguments it binds as typed for
    /// omniwmctl (joined by spaces), or nil arguments when it binds none.
    static func invocation(for command: HotkeyCommand) -> (name: IPCCommandName, arguments: String?)? {
        guard let name = ActionCatalog.spec(for: command)?.ipcCommandName,
              let descriptor = IPCAutomationManifest.commandDescriptor(for: name)
        else { return nil }
        guard !descriptor.arguments.isEmpty else { return (name, nil) }
        for candidate in argumentCandidates(for: descriptor.arguments) {
            guard let request = IPCCommandRequest(commandWords: descriptor.commandWords + candidate),
                  hotkeyCommand(for: request) == command
            else { continue }
            return (name, candidate.joined(separator: " "))
        }
        // The hotkey runs the command without fixing its arguments (it asks, or
        // uses the focused window's state), so it binds the command as a whole.
        return (name, nil)
    }

    private static func title(for descriptor: IPCCommandDescriptor, specs: [ActionSpec]) -> String {
        let titles = specs.map(\.localizedTitle)
        if titles.count == 1 {
            return titles[0]
        }
        // Per-argument actions ("Focus Left", "Focus Right", …) share their leading words.
        if let first = titles.first {
            var common = first.split(separator: " ")
            for title in titles.dropFirst() {
                let words = title.split(separator: " ")
                common = Array(zip(common, words).prefix { $0 == $1 }.map(\.0))
            }
            if !common.isEmpty {
                return common.joined(separator: " ")
            }
        }
        let words = descriptor.commandWords.joined(separator: " ").replacingOccurrences(of: "-", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    private static let numberCandidates = (1 ... 99).map(String.init)

    private static func argumentCandidates(for arguments: [IPCCommandArgumentDescriptor]) -> [[String]] {
        arguments.reduce([[]]) { partial, argument in
            let values: [String] = switch argument.kind {
            case .workspaceNumber,
                 .columnIndex,
                 .windowIndex,
                 .scratchpadIndex:
                numberCandidates
            case .sizeChange:
                []
            default:
                argument.choices ?? []
            }
            return partial.flatMap { prefix in values.map { prefix + [$0] } }
        }
    }

    /// The hotkey command an IPC command request runs, for requests a hotkey can bind.
    static func hotkeyCommand(for request: IPCCommandRequest) -> HotkeyCommand? {
        switch request {
        case let .focus(command):
            HotkeyCommand(ipc: command)
        case let .windowMovement(command):
            HotkeyCommand(ipc: command)
        case let .column(command):
            HotkeyCommand(ipc: command)
        case let .sizing(command):
            HotkeyCommand(ipc: command)
        case let .dwindle(command):
            HotkeyCommand(ipc: command)
        case let .scratchpad(command):
            HotkeyCommand(ipc: command)
        case let .workspace(command):
            hotkeyCommand(for: command)
        case let .monitorFocus(command):
            .monitorFocus(command)
        case let .swapWorkspaceWithMonitor(direction):
            .workspace(.swapWithMonitor(Direction(ipc: direction)))
        case .openCommandPalette:
            .openCommandPalette
        case let .openCommandPaletteMode(mode):
            .openCommandPaletteMode(mode)
        case .raiseAllFloatingWindows:
            .raiseAllFloatingWindows
        case .toggleFloatingFocus:
            .toggleFloatingFocus
        case .rescueOffscreenWindows:
            .rescueOffscreenWindows
        case let .workspaceLayout(command):
            command == .toggle ? .workspace(.toggleLayout) : nil
        case let .fullscreen(command):
            .fullscreen(command)
        case let .presentation(command):
            .presentation(command)
        case let .media(command):
            .media(command)
        case let .keyboardMode(command):
            .keyboardMode(command)
        case let .windowState(command):
            .windowState(command)
        case .openMenuAnywhere:
            .openMenuAnywhere
        }
    }

    private static func hotkeyCommand(for command: IPCWorkspaceCommand) -> HotkeyCommand? {
        switch command {
        case let .switchTo(workspaceNumber):
            .workspace(.switchTo(workspaceNumber - 1))
        case .next:
            .workspace(.next)
        case .previous:
            .workspace(.previous)
        case .backAndForth:
            .workspace(.backAndForth)
        case let .switchSlot(slotNumber):
            .workspace(.switchSlot(slotNumber))
        case .switchToNew:
            .workspace(.switchToNew)
        case let .moveTo(workspaceNumber):
            .workspace(.moveTo(workspaceNumber - 1))
        case .moveUp:
            .workspace(.moveUp)
        case .moveDown:
            .workspace(.moveDown)
        case .moveNext:
            .workspace(.moveNext)
        case .movePrevious:
            .workspace(.movePrevious)
        case let .moveToSlot(slotNumber):
            .workspace(.moveToSlot(slotNumber))
        case .moveToNew:
            .workspace(.moveToNew)
        case let .moveToMonitor(direction):
            .workspace(.moveToMonitor(Direction(ipc: direction)))
        case .switchAnywhere,
             .moveToOnMonitor:
            nil
        }
    }
}
