// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation
import OmniWMIPC

enum WorkspaceAction: Equatable, Hashable {
    case moveTo(Int)
    case moveUp
    case moveDown
    case moveNext
    case movePrevious
    case moveToNew
    case moveToMonitor(Direction)
    case switchTo(Int)
    case switchSlot(Int)
    case moveToSlot(Int)
    case next
    case previous
    case switchToNew
    case moveWorkspaceToMonitor(Direction)
    case swapWithMonitor(Direction)
    case backAndForth
    case toggleLayout
}

extension WorkspaceAction {
    func actionDisplayName() -> LocalizedStringResource {
        switch self {
        case let .moveTo(idx): LocalizedStringResource(
                "command.workspace.moveTo", defaultValue: "Move Focused Window to Workspace \(idx + 1)",
                table: "Commands", bundle: .omniWM
            )
        case .moveUp: LocalizedStringResource(
                "command.workspace.moveWindowUp", defaultValue: "Move Focused Window to Workspace Up",
                table: "Commands", bundle: .omniWM
            )
        case .moveDown: LocalizedStringResource(
                "command.workspace.moveWindowDown", defaultValue: "Move Focused Window to Workspace Down",
                table: "Commands", bundle: .omniWM
            )
        case .moveNext: Self.moveRelativeTitle(isNext: true)
        case .movePrevious: Self.moveRelativeTitle(isNext: false)
        case .moveToNew: Self.newWorkspaceTitle(movesFocusedWindow: true)
        case let .switchTo(idx): LocalizedStringResource(
                "command.workspace.switchTo", defaultValue: "Switch to Workspace \(idx + 1)", table: "Commands",
                bundle: .omniWM
            )
        case let .switchSlot(slot): LocalizedStringResource(
                "command.workspace.switchSlot", defaultValue: "Switch to Workspace Slot \(slot)", table: "Commands",
                bundle: .omniWM
            )
        case let .moveToSlot(slot): LocalizedStringResource(
                "command.workspace.moveToSlot", defaultValue: "Move Focused Window to Workspace Slot \(slot)",
                table: "Commands", bundle: .omniWM
            )
        case .next: LocalizedStringResource(
                "command.workspace.next", defaultValue: "Switch to Next Workspace", table: "Commands", bundle: .omniWM
            )
        case .previous: LocalizedStringResource(
                "command.workspace.previous", defaultValue: "Switch to Previous Workspace", table: "Commands",
                bundle: .omniWM
            )
        case .switchToNew: Self.newWorkspaceTitle(movesFocusedWindow: false)
        case let .moveToMonitor(direction): Self.moveToMonitorTitle(direction)
        case let .moveWorkspaceToMonitor(direction): Self.moveWorkspaceToMonitorTitle(direction)
        case let .swapWithMonitor(direction): Self.swapWithMonitorTitle(direction)
        case .backAndForth: LocalizedStringResource(
                "command.workspace.backAndForth", defaultValue: "Switch to Last Active Workspace", table: "Commands",
                bundle: .omniWM
            )
        case .toggleLayout: LocalizedStringResource(
                "command.workspace.toggleLayout", defaultValue: "Toggle Workspace Layout", table: "Commands",
                bundle: .omniWM
            )
        }
    }

    private static func moveRelativeTitle(isNext: Bool) -> LocalizedStringResource {
        if isNext {
            LocalizedStringResource(
                "command.workspace.moveWindowNext", defaultValue: "Move Focused Window to Next Workspace",
                table: "Commands", bundle: .omniWM
            )
        } else {
            LocalizedStringResource(
                "command.workspace.moveWindowPrevious", defaultValue: "Move Focused Window to Previous Workspace",
                table: "Commands", bundle: .omniWM
            )
        }
    }

    private static func newWorkspaceTitle(movesFocusedWindow: Bool) -> LocalizedStringResource {
        if movesFocusedWindow {
            LocalizedStringResource(
                "command.workspace.moveToNew", defaultValue: "Move Focused Window to New Workspace",
                table: "Commands", bundle: .omniWM
            )
        } else {
            LocalizedStringResource(
                "command.workspace.switchToNew", defaultValue: "Switch to New Workspace", table: "Commands",
                bundle: .omniWM
            )
        }
    }

    private static func moveToMonitorTitle(_ direction: Direction) -> LocalizedStringResource {
        switch direction {
        case .left: LocalizedStringResource(
                "command.workspace.moveWindowToMonitor.left", defaultValue: "Move Focused Window to Monitor on Left",
                table: "Commands", bundle: .omniWM
            )
        case .right: LocalizedStringResource(
                "command.workspace.moveWindowToMonitor.right", defaultValue: "Move Focused Window to Monitor on Right",
                table: "Commands", bundle: .omniWM
            )
        case .up: LocalizedStringResource(
                "command.workspace.moveWindowToMonitor.up", defaultValue: "Move Focused Window to Monitor Above",
                table: "Commands", bundle: .omniWM
            )
        case .down: LocalizedStringResource(
                "command.workspace.moveWindowToMonitor.down", defaultValue: "Move Focused Window to Monitor Below",
                table: "Commands", bundle: .omniWM
            )
        }
    }

    private static func moveWorkspaceToMonitorTitle(_ direction: Direction) -> LocalizedStringResource {
        switch direction {
        case .left: LocalizedStringResource(
                "command.workspace.moveToMonitor.left", defaultValue: "Move Workspace to Monitor on Left",
                table: "Commands", bundle: .omniWM
            )
        case .right: LocalizedStringResource(
                "command.workspace.moveToMonitor.right", defaultValue: "Move Workspace to Monitor on Right",
                table: "Commands", bundle: .omniWM
            )
        case .up: LocalizedStringResource(
                "command.workspace.moveToMonitor.up", defaultValue: "Move Workspace to Monitor Above",
                table: "Commands", bundle: .omniWM
            )
        case .down: LocalizedStringResource(
                "command.workspace.moveToMonitor.down", defaultValue: "Move Workspace to Monitor Below",
                table: "Commands", bundle: .omniWM
            )
        }
    }

    private static func swapWithMonitorTitle(_ direction: Direction) -> LocalizedStringResource {
        switch direction {
        case .left: LocalizedStringResource(
                "command.workspace.swapWithMonitor.left", defaultValue: "Swap Workspace with Monitor on Left",
                table: "Commands", bundle: .omniWM
            )
        case .right: LocalizedStringResource(
                "command.workspace.swapWithMonitor.right", defaultValue: "Swap Workspace with Monitor on Right",
                table: "Commands", bundle: .omniWM
            )
        case .up: LocalizedStringResource(
                "command.workspace.swapWithMonitor.up", defaultValue: "Swap Workspace with Monitor Above",
                table: "Commands", bundle: .omniWM
            )
        case .down: LocalizedStringResource(
                "command.workspace.swapWithMonitor.down", defaultValue: "Swap Workspace with Monitor Below",
                table: "Commands", bundle: .omniWM
            )
        }
    }

    func ipcCommandName() -> IPCCommandName? {
        switch self {
        case .switchTo:
            .workspace(.switchTo)
        case .switchSlot:
            .workspace(.switchSlot)
        case .moveToSlot:
            .workspace(.moveToSlot)
        case .next:
            .workspace(.next)
        case .previous:
            .workspace(.previous)
        case .switchToNew:
            .workspace(.switchToNew)
        case .backAndForth:
            .workspace(.backAndForth)
        case .moveTo:
            .workspace(.moveTo)
        case .moveUp:
            .workspace(.moveUp)
        case .moveDown:
            .workspace(.moveDown)
        case .moveNext:
            .workspace(.moveNext)
        case .movePrevious:
            .workspace(.movePrevious)
        case .moveToNew:
            .workspace(.moveToNew)
        case .moveToMonitor:
            .workspace(.moveToMonitor)
        case .moveWorkspaceToMonitor:
            nil
        case .swapWithMonitor:
            .swapWorkspaceWithMonitor
        case .toggleLayout:
            .workspaceLayout(.toggle)
        }
    }

    var compatibility: LayoutCompatibility {
        switch self {
        case .moveTo,
             .moveUp,
             .moveDown,
             .moveNext,
             .movePrevious,
             .moveToNew,
             .moveToMonitor,
             .switchTo,
             .switchSlot,
             .moveToSlot,
             .next,
             .previous,
             .switchToNew,
             .moveWorkspaceToMonitor,
             .swapWithMonitor,
             .backAndForth,
             .toggleLayout:
            .shared
        }
    }
}
