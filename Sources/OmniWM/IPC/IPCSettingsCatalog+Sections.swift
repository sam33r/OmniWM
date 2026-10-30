// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

extension IPCSettingsCatalog {
    static let sections: [IPCSettingsCatalogSection] = [
        IPCSettingsCatalogSection(id: "general", title: "General", entries: [
            .init(
                "general.language",
                "App Language",
                .string,
                "Interface language as a packaged localization code such as ja or sr-Latn. Leave it unset to follow macOS. Takes effect the next time OmniWM starts."
            ),
            .init(
                "general.updateChecksEnabled",
                "Check for Updates Automatically",
                .bool,
                "Checks for new OmniWM releases automatically."
            ),
            .init(
                "general.animationsEnabled",
                "Enable Animations",
                .bool,
                "Animates window layout changes and other OmniWM motion. macOS Reduce Motion turns animations off regardless."
            ),
            .init(
                "general.animationSpeed",
                "Tiling Animation Speed",
                .number(min: 0.25, max: 4.0, step: 0.25),
                "Tiling animation speed multiplier: 2 is twice as fast, 0.5 half as fast. Applies to newly started Niri, Dwindle and workspace swipe transitions."
            ),
            .init(
                "general.defaultLayoutType",
                "Default Layout",
                .choice([
                    .init(value: "niri", title: "Niri (Scrolling)"),
                    .init(value: "dwindle", title: "Dwindle (BSP)")
                ]),
                "Layout used by workspaces whose own layout is set to Default."
            ),
            .init(
                "general.workspaceAutoBackAndForth",
                "Go Back When Switching to the Current Workspace",
                .bool,
                "A workspace shortcut or command palette entry for the workspace you are already on switches to the previous workspace instead. omniwmctl is unaffected."
            ),
            .init(
                "general.systemHyperTrigger",
                "System Hyper Trigger",
                .string,
                "Key or mouse button held as Hyper: None, a key name such as Caps Lock, F13 or Right Command, or MouseButton3, MouseButton4 or MouseButton5."
            ),
            .init(
                "general.hyperKeyModifiers",
                "Hyper Key Modifiers",
                .string,
                "Modifiers Hyper expands to, joined with +, using at least two of Control, Option, Shift and Command."
            ),
            .init("general.hotkeysEnabled", "Enable Hotkeys", .bool, "Master switch for all global hotkeys."),
            .init(
                "general.preventSleepEnabled",
                "Keep Awake",
                .bool,
                "Prevents idle display sleep while your user session is active."
            )
        ]),
        IPCSettingsCatalogSection(id: "appearance", title: "Appearance", entries: [
            .init(
                "appearance.mode",
                "App Appearance",
                .choice([
                    .init(value: "automatic", title: "Automatic"),
                    .init(value: "light", title: "Light"),
                    .init(value: "dark", title: "Dark")
                ]),
                "Appearance of OmniWM's own interface: follow macOS, or always light or dark."
            ),
            .init(
                "appearance.tabRailAppIcons",
                "Show app icons in tab rails",
                .bool,
                "Replaces compact tab markers with app icons in Niri and Dwindle tab groups, which then reserve a wider rail."
            )
        ]),
        IPCSettingsCatalogSection(id: "borders", title: "Borders", entries: [
            .init("borders.enabled", "Enable Borders", .bool, "Draws a border around the focused window."),
            .init(
                "borders.width",
                "Border Width",
                .number(min: 1.0, max: 12.0, step: 0.5),
                "Exterior border width in points. While borders are on, layout clearance grows to fit it without changing the stored gaps."
            ),
            .init(
                "borders.gradient.enabled",
                "Gradient Border",
                .bool,
                "Draws the border as a two-color linear gradient instead of the solid color."
            ),
            .init(
                "borders.gradient.direction",
                "Gradient Direction",
                .choice([
                    .init(value: "topLeftToBottomRight", title: "Top Left → Bottom Right"),
                    .init(value: "topRightToBottomLeft", title: "Top Right → Bottom Left")
                ]),
                "Direction of the border gradient."
            ),
            .init(
                "borders.glow.enabled",
                "Glow",
                .bool,
                "Draws a visual-only glow around the border. It never changes gaps or resize hit-testing."
            ),
            .init(
                "borders.glow.radius",
                "Glow Radius",
                .number(min: 0.0, max: 32.0, step: 1.0),
                "Radius of the border glow in points."
            ),
            .init(
                "borders.glow.opacity",
                "Glow Opacity",
                .number(min: 0.0, max: 1.0, step: 0.05),
                "Opacity of the border glow."
            )
        ]),
        IPCSettingsCatalogSection(id: "workspaceBar", title: "Workspace Bar", entries: [
            .init(
                "workspaceBar.position",
                "Position",
                .choice([
                    .init(value: "overlappingMenuBar", title: "Overlapping Menu Bar"),
                    .init(value: "belowMenuBar", title: "Below Menu Bar"),
                    .init(value: "bottom", title: "Bottom"),
                    .init(value: "left", title: "Left"),
                    .init(value: "right", title: "Right")
                ]),
                "Screen edge the workspace bar sits on. Bottom and side placements avoid a visible Dock."
            ),
            .init(
                "workspaceBar.fullWidth",
                "Full Width",
                .bool,
                "Spans the whole screen edge with widget groups at its start, middle and end. While enabled, macOS automatically hides the menu bar."
            ),
            .init(
                "workspaceBar.windowLevel",
                "Window Level",
                .choice([
                    .init(value: "normal", title: "Normal"),
                    .init(value: "floating", title: "Floating"),
                    .init(value: "status", title: "Status Bar"),
                    .init(value: "popup", title: "Popup"),
                    .init(value: "screensaver", title: "Screen Saver")
                ]),
                "Window level of the bar, which decides which windows it stays above."
            ),
            .init("workspaceBar.xOffset", "X Offset", .number(step: 10.0), "Horizontal offset of the bar in points."),
            .init(
                "workspaceBar.yOffset",
                "Y Offset",
                .number(step: 10.0),
                "Vertical offset of the bar in points; positive values move it up."
            ),
            .init(
                "workspaceBar.reserveLayoutSpace",
                "Reserve Space for Workspace Bar",
                .bool,
                "Reserves space at the bar's edge so tiled and layout-fullscreen windows stay clear of it."
            ),
            .init(
                "workspaceBar.notchMode",
                "Notch Mode",
                .choice([
                    .init(value: "off", title: "Off"),
                    .init(value: "moveBelowMenuBar", title: "Move Below Menu Bar"),
                    .init(value: "rightOfNotch", title: "Right of Notch"),
                    .init(value: "splitActiveLeft", title: "Split — Active Left"),
                    .init(value: "splitActiveRight", title: "Split — Active Right"),
                    .init(value: "fillLeftOfNotch", title: "Fill Left of Notch")
                ]),
                "How a top bar handles the notch: ignore it, move below the menu bar, split around it, or fill the menu bar left of it."
            ),
            .init(
                "workspaceBar.fullWidthNotchMode",
                "Full Width Notch Mode",
                .choice([
                    .init(value: "off", title: "Off"),
                    .init(value: "moveBelowMenuBar", title: "Move Below Menu Bar"),
                    .init(value: "rightOfNotch", title: "Right of Notch"),
                    .init(value: "leftOfNotch", title: "Left of Notch"),
                    .init(value: "splitAroundNotch", title: "Split Around Notch")
                ]),
                "Where a full-width bar's center widgets go on a display with a notch."
            ),
            .init(
                "workspaceBar.notchActiveZoneWidth",
                "Active Zone Width",
                .number(min: 100.0, max: 400.0, step: 10.0),
                "Width in points of the zone beside the notch that the focused workspace stays centered in, for the split notch modes."
            ),
            .init(
                "workspaceBar.height",
                "Bar Thickness",
                .number(min: 20.0, max: 200.0, step: 2.0),
                "Bar thickness in points: height for top and bottom bars, width for side bars."
            ),
            .init(
                "workspaceBar.backgroundOpacity",
                "Background Opacity",
                .number(min: 0.0, max: 1.0, step: 0.05),
                "Opacity of the bar background."
            ),
            .init(
                "workspaceBar.inactiveIconOpacity",
                "Inactive Icon Opacity",
                .number(min: 0.0, max: 1.0, step: 0.05),
                "Opacity of unfocused app icons. Unset uses the built-in appearance."
            ),
            .init(
                "workspaceBar.transparentBackground",
                "Transparent Background",
                .bool,
                "Hides the bar material, tint and border while keeping its contents interactive."
            ),
            .init(
                "workspaceBar.showItemBackgrounds",
                "Show Item Backgrounds",
                .bool,
                "Shows backgrounds behind workspace groups, floating windows, scratchpads and stats."
            ),
            .init(
                "workspaceBar.solidBlackBackground",
                "Solid Black Background",
                .bool,
                "Fills the bar with solid black. Takes precedence over a transparent background."
            ),
            .init(
                "workspaceBar.showAccentHighlights",
                "Show Accent Highlights",
                .bool,
                "Shows the focused-workspace outline and the focused-icon glow."
            ),
            .init(
                "workspaceBar.hoverPreviewsEnabled",
                "Window Hover Previews",
                .bool,
                "Shows window thumbnail previews when hovering over bar icons."
            ),
            .init(
                "workspaceBar.notificationBadges",
                "Notification Badges",
                .choice([
                    .init(value: "off", title: "Off"),
                    .init(value: "dot", title: "Dot"),
                    .init(value: "text", title: "Text")
                ]),
                "Shows apps' Dock badges on their bar icons as a dot or as text."
            ),
            .init(
                "workspaceBar.notificationBadgeRefreshIntervalSeconds",
                "Badge Refresh Interval",
                .number(min: 1.0, max: 60.0, step: 1.0),
                "Seconds between notification badge refreshes."
            ),
            .init(
                "workspaceBar.showLabels",
                "Show Workspace Labels",
                .bool,
                "Shows workspace names next to their numbers."
            ),
            .init(
                "workspaceBar.showFloatingWindows",
                "Show Floating Windows",
                .bool,
                "Includes floating windows' icons in workspace pills."
            ),
            .init(
                "workspaceBar.deduplicateAppIcons",
                "Deduplicate App Icons",
                .bool,
                "Collapses repeated icons of the same app within a workspace pill into one icon with a count."
            ),
            .init(
                "workspaceBar.hideEmptyWorkspaces",
                "Hide Empty Workspaces",
                .bool,
                "Hides inactive empty workspaces in the bar and Overview; next and previous navigation skips them."
            ),
            .init(
                "workspaceBar.autoHide",
                "Automatically hide and show the workspace bar",
                .bool,
                "Reveals the bar when the pointer touches its edge and hides it once the pointer moves inward past it. Never reserves layout space."
            ),
            .init(
                "workspaceBar.autoHideRevealDelayMilliseconds",
                "Auto-Hide Reveal Delay",
                .number(min: 0.0, max: 1000.0, step: 50.0),
                "Milliseconds the pointer must stay at the edge before an auto-hidden bar appears."
            ),
            .init(
                "workspaceBar.autoHideHideDelayMilliseconds",
                "Auto-Hide Hide Delay",
                .number(min: 0.0, max: 1000.0, step: 50.0),
                "Milliseconds an auto-hidden bar stays after the pointer moves away and interactions end."
            ),
            .init(
                "workspaceBar.revealModifier",
                "Reveal on Modifier Hold",
                .choice([
                    .init(value: "off", title: "Off"),
                    .init(value: "option", title: "Option"),
                    .init(value: "control", title: "Control"),
                    .init(value: "command", title: "Command"),
                    .init(value: "shift", title: "Shift"),
                    .init(value: "controlOption", title: "Control+Option"),
                    .init(value: "optionCommand", title: "Option+Command"),
                    .init(value: "optionShift", title: "Option+Shift"),
                    .init(value: "controlCommand", title: "Control+Command"),
                    .init(value: "controlShift", title: "Control+Shift"),
                    .init(value: "commandShift", title: "Command+Shift"),
                    .init(value: "controlOptionCommand", title: "Control+Option+Command"),
                    .init(value: "controlOptionShift", title: "Control+Option+Shift"),
                    .init(value: "optionCommandShift", title: "Option+Command+Shift"),
                    .init(value: "controlCommandShift", title: "Control+Command+Shift"),
                    .init(value: "controlOptionCommandShift", title: "Control+Option+Command+Shift")
                ]),
                "Reveals the bar while these modifiers are held. Any value other than Off makes the bar overlay-only, reserving no layout space."
            ),
            .init(
                "workspaceBar.revealHoldMilliseconds",
                "Reveal Hold Delay",
                .number(min: 0.0, max: 1000.0, step: 50.0),
                "Milliseconds the reveal modifier must be held before the bar appears."
            ),
            .init(
                "workspaceBar.hideInNativeFullscreen",
                "Hide in Native Fullscreen",
                .bool,
                "Hides the bar while a native fullscreen space is active."
            ),
            .init(
                "workspaceBar.systemStatsButton",
                "System Stats Button",
                .bool,
                "Adds a bar button that opens a system stats popup. Needs the shell's system-stats widget in the bar."
            ),
            .init(
                "workspaceBar.enabled",
                "Enable Workspace Bar",
                .bool,
                "Shows the workspace bar. When off, every display's bar is off, including per-display overrides."
            )
        ]),
        IPCSettingsCatalogSection(id: "island", title: "Dynamic Island", entries: [
            .init(
                "island.enabled",
                "Show Dynamic Island",
                .bool,
                "Shows the active shell profile's Dynamic Island, independently of the workspace bar."
            )
        ]),
        IPCSettingsCatalogSection(id: "statusBar", title: "Status Bar", entries: [
            .init(
                "statusBar.showWorkspaceName",
                "Show Workspace",
                .bool,
                "Shows the active workspace beside the OmniWM menu bar icon."
            ),
            .init(
                "statusBar.useWorkspaceId",
                "Use Workspace Number",
                .bool,
                "Shows the workspace number instead of its name."
            ),
            .init("statusBar.showAppNames", "Show Focused App", .bool, "Also shows the focused app's name."),
            .init(
                "statusBar.showIcon",
                "Show Menu Bar Icon",
                .bool,
                "Shows the OmniWM icon beside the workspace. Has no effect while Show Workspace is off."
            )
        ]),
        IPCSettingsCatalogSection(id: "hiddenBar", title: "Hidden Bar", entries: [
            .init(
                "hiddenBar.enabled",
                "Enable Hidden Bar",
                .bool,
                "Conceals the selected menu bar icons while the workspace bar is on. Needs macOS 27 or later and Full Disk Access."
            ),
            .init(
                "hiddenBar.rehideIntervalSeconds",
                "Rehide Delay",
                .number(min: 2.0, max: 30.0, step: 1.0),
                "Seconds before revealed menu bar icons hide again."
            )
        ]),
        IPCSettingsCatalogSection(id: "gaps", title: "Gaps", entries: [
            .init(
                "gaps.size",
                "Inner Gaps",
                .number(min: 0.0, max: 64.0, step: 1.0),
                "Gap between tiled windows in points. An enabled focus border may raise the effective gap."
            ),
            .init(
                "gaps.outer.left",
                "Left Outer Margin",
                .number(min: 0.0, max: 64.0, step: 1.0),
                "Outer gap at the left screen edge in points."
            ),
            .init(
                "gaps.outer.right",
                "Right Outer Margin",
                .number(min: 0.0, max: 64.0, step: 1.0),
                "Outer gap at the right screen edge in points."
            ),
            .init(
                "gaps.outer.top",
                "Top Outer Margin",
                .number(min: 0.0, max: 64.0, step: 1.0),
                "Outer gap from the top edge of each display in points. The menu bar height is subtracted first."
            ),
            .init(
                "gaps.outer.bottom",
                "Bottom Outer Margin",
                .number(min: 0.0, max: 64.0, step: 1.0),
                "Outer gap at the bottom screen edge in points."
            ),
            .init(
                "gaps.fullscreenUsesOuterGaps",
                "Keep Outer Margins in Full Screen",
                .bool,
                "Keeps the outer margins for OmniWM full screen and the Full Screen single-window fit."
            )
        ]),
        IPCSettingsCatalogSection(id: "niri", title: "Niri", entries: [
            .init(
                "niri.visibleContainerCount",
                "Visible Containers",
                .int(min: 1, max: 5, step: 1),
                "How many columns share the viewport side by side. With fewer columns open, they expand to fill the space."
            ),
            .init(
                "niri.infiniteLoop",
                "Infinite Loop Navigation",
                .bool,
                "Treats the column strip as a loop instead of a bounded row."
            ),
            .init(
                "niri.centerFocusedColumn",
                "Center Focused Column",
                .choice([
                    .init(value: "never", title: "Never"),
                    .init(value: "always", title: "Always"),
                    .init(value: "onOverflow", title: "On Overflow")
                ]),
                "When to center the focused column in the view."
            ),
            .init(
                "niri.alwaysCenterSingleColumn",
                "Always Center Single Column",
                .bool,
                "Centers the column when a workspace holds only one."
            ),
            .init(
                "niri.allowOverscroll",
                "Allow Overscroll",
                .bool,
                "Lets trackpad scrolling go past the first or last column and leave the desktop showing after release."
            ),
            .init(
                "niri.overscrollVisibleStripPercent",
                "Overscroll Visible Strip",
                .int(min: 1, max: 100, step: 1),
                "How much of the edge column stays visible at either overscroll limit, as a percentage of its width. Used only with overscroll allowed."
            ),
            .init(
                "niri.edgeGaps",
                "Gaps at Screen Edges",
                .bool,
                "Keeps the inner gap between columns and the screen edges, in addition to the outer gaps."
            ),
            .init(
                "niri.moveWindowStacksIntoColumn",
                "Stack Moved Window Into Adjacent Column",
                .bool,
                "Moving a lone window left or right stacks it into the adjacent column. When off, its column swaps with the neighbor instead."
            ),
            .init(
                "niri.singleWindowFit",
                "Single Window",
                .string,
                "Size of a lone window: fill for full screen, container_primary_span, or a custom WIDTHxHEIGHT such as 1920x1080."
            ),
            .init(
                "niri.resizeStepPercent",
                "Resize Increment",
                .int(min: 1, max: 100),
                "Percentage points the Niri grow and shrink actions change a span by."
            ),
            .init(
                "niri.defaultContainerPrimarySpan",
                "Default New Container Primary Span",
                .number(min: 0.05, max: 1.0),
                "Primary-axis span fraction for new columns, such as 0.5 for half the view."
            )
        ]),
        IPCSettingsCatalogSection(id: "dwindle", title: "Dwindle", entries: [
            .init(
                "dwindle.smartSplit",
                "Smart Split",
                .bool,
                "Chooses the split direction from where the active window sits relative to the target tile."
            ),
            .init(
                "dwindle.moveToRootStable",
                "Move to Root: Stable",
                .bool,
                "Keeps a window on the same side of the screen when moving it to the root."
            ),
            .init(
                "dwindle.defaultSplitRatio",
                "Default Split Ratio",
                .number(min: 0.1, max: 1.9, step: 0.1),
                "Ratio for new splits: 1 is equal, below 1 makes the first window smaller, above 1 larger."
            ),
            .init(
                "dwindle.splitWidthMultiplier",
                "Split Width Multiplier",
                .number(min: 0.5, max: 2.0, step: 0.1),
                "Biases whether vertical or horizontal splits are preferred."
            ),
            .init(
                "dwindle.singleWindowFit",
                "Single Window",
                .string,
                "Size of a lone window: fill for full screen, or a custom WIDTHxHEIGHT such as 1920x1080."
            ),
            .init(
                "dwindle.useGlobalGaps",
                "Use Global Gap Settings",
                .bool,
                "Uses the global gap values. When off, the inner gap comes from each display's Dwindle override."
            )
        ]),
        IPCSettingsCatalogSection(id: "routing", title: "Routing", entries: [
            .init(
                "routing.mode",
                "Arrangement",
                .choice([
                    .init(value: "macOS", title: "Use macOS Arrangement"),
                    .init(value: "custom", title: "Custom Arrangement")
                ]),
                "Monitor arrangement for cross-monitor focus, move and warp: the macOS arrangement or a saved custom one."
            )
        ]),
        IPCSettingsCatalogSection(id: "focus", title: "Focus", entries: [
            .init(
                "focus.crossesMonitorAtEdge",
                "Focus Across Monitor at Edge",
                .bool,
                "Directional focus continues onto the neighboring monitor at the screen edge."
            ),
            .init(
                "focus.moveCrossesMonitorAtEdge",
                "Move Window Across Monitor at Edge",
                .bool,
                "Directional window moves continue onto the neighboring monitor at the workspace edge and follow the window."
            ),
            .init(
                "focus.followsWindowToMonitor",
                "Follow Window to Monitor",
                .bool,
                "Follows a window or column you move to another workspace or monitor. Edge-crossing moves always follow."
            ),
            .init(
                "focus.moveToMonitorWrapsAround",
                "Move Window to Monitor Wraps Around",
                .bool,
                "Moving a window toward a direction with no monitor sends it to the farthest monitor on the other side of the same row or column."
            ),
            .init(
                "focus.followsMouse",
                "Enable Focus Follows Mouse",
                .bool,
                "Focuses a managed window when the pointer enters it, without a click."
            ),
            .init(
                "focus.raiseOnMouseFocus",
                "Raise Window When Focus Follows Mouse",
                .bool,
                "Also raises the window when focus follows the mouse to it."
            ),
            .init(
                "focus.followsMouseMaxScrollPercent",
                "Maximum Mouse Focus Scroll",
                .int(min: 0, max: 100, step: 5),
                "In Niri, hovering a window doesn't focus it if revealing it would scroll the view by more than this percentage. Unset means no limit."
            ),
            .init(
                "focus.followsMouseOnlyFullyVisible",
                "Only Focus Fully Visible Niri Windows",
                .bool,
                "Ignores partially offscreen Niri windows and turns off hover navigation at screen edges. Click or use the keyboard to reveal them."
            ),
            .init(
                "focus.edgeNavigationInterval",
                "Edge navigation interval",
                .number(min: 0.25, max: 2.0, step: 0.25),
                "Seconds before hovering at a Niri edge moves one column, and between further moves. Requires focus follows mouse."
            ),
            .init(
                "focus.lockModifier",
                "Focus Lock Modifier",
                .choice([
                    .init(value: "off", title: "Off"),
                    .init(value: "option", title: "Option"),
                    .init(value: "leftOption", title: "Left Option"),
                    .init(value: "rightOption", title: "Right Option"),
                    .init(value: "command", title: "Command"),
                    .init(value: "leftCommand", title: "Left Command"),
                    .init(value: "rightCommand", title: "Right Command"),
                    .init(value: "control", title: "Control"),
                    .init(value: "leftControl", title: "Left Control"),
                    .init(value: "rightControl", title: "Right Control"),
                    .init(value: "shift", title: "Shift"),
                    .init(value: "leftShift", title: "Left Shift"),
                    .init(value: "rightShift", title: "Right Shift")
                ]),
                "Hold this modifier to move the pointer over other windows without changing focus."
            ),
            .init(
                "focus.moveMouseToFocusedWindow",
                "Move Mouse to Focused Window",
                .bool,
                "Moves the pointer to the window that gains focus."
            ),
            .init(
                "focus.relativeWorkspaceEdgeBehavior",
                "Relative Workspace Edge Behavior",
                .choice([
                    .init(value: "cycle", title: "Wrap Around"),
                    .init(value: "none", title: "Stop"),
                    .init(value: "onePast", title: "Open One Empty Workspace")
                ]),
                "What next and previous workspace commands do past the last or first workspace: wrap around, stop, or open one empty workspace like niri."
            ),
            .init(
                "focus.dimUnfocused",
                "Dim Unfocused Windows",
                .bool,
                "Darkens everything except the focused managed window on every display."
            ),
            .init(
                "focus.dimUnfocusedOpacity",
                "Dim Unfocused Opacity",
                .number(min: 0.1, max: 0.95),
                "Opacity of the dark layer that dims unfocused windows; higher is darker."
            )
        ]),
        IPCSettingsCatalogSection(id: "mouseWarp", title: "Mouse Warp", entries: [
            .init(
                "mouseWarp.enabled",
                "Mouse Warp",
                .bool,
                "Moves the pointer across matching display edges using the routing arrangement."
            ),
            .init(
                "mouseWarp.constrainToArrangement",
                "Constrain Cursor to Arrangement",
                .bool,
                "Keeps the pointer inside the custom monitor arrangement."
            ),
            .init(
                "mouseWarp.margin",
                "Mouse Warp Margin",
                .int(min: 1, max: 10, step: 1),
                "Edge margin in pixels used when warping the pointer between monitors."
            )
        ]),
        IPCSettingsCatalogSection(id: "monitors", title: "Monitors", entries: [
            .init(
                "monitors.defaultOrientation",
                "Default Orientation",
                .choice([
                    .init(value: "auto", title: "Auto"),
                    .init(value: "horizontal", title: "Horizontal"),
                    .init(value: "vertical", title: "Vertical")
                ]),
                "Niri orientation for displays without an override. Auto makes portrait displays vertical."
            )
        ]),
        IPCSettingsCatalogSection(id: "overview", title: "Overview", entries: [
            .init(
                "overview.enabled",
                "Enable Overview",
                .bool,
                "Enables Overview. When off, its shortcuts, mouse button, gesture and commands can't open it."
            ),
            .init(
                "overview.zoom",
                "Zoom",
                .number(min: 0.5, max: 1.5, step: 0.05),
                "Overview zoom factor. Zoom changes made in Overview are saved when it closes."
            ),
            .init(
                "overview.invertScrollDirection",
                "Invert Scrolling Direction",
                .bool,
                "Reverses mouse and trackpad scrolling in Overview relative to the system Natural Scrolling setting."
            ),
            .init(
                "overview.mouseScrollSpeed",
                "Mouse Wheel Speed",
                .number(min: 0.05, max: 2.0, step: 0.05),
                "Mouse wheel speed multiplier in Overview. Trackpad speed is unaffected."
            ),
            .init(
                "overview.mouseButton",
                "Toggle Overview Mouse Button",
                .int(min: 2, max: 5),
                "Mouse button that opens and closes Overview; 2 is the middle button. Unset leaves it unassigned."
            ),
            .init(
                "overview.matchFocusBorder",
                "Selected Border Matches Focus Border",
                .bool,
                "Uses the focused-window border's appearance for the selected Overview card."
            ),
            .init(
                "overview.fitWorkspaceRows",
                "Fit Workspace Rows",
                .int(min: 2, max: 6),
                "Sizes workspace rows so each monitor's workspaces fit on screen, showing up to this many rows before scrolling. Unset keeps the fixed row size."
            )
        ]),
        IPCSettingsCatalogSection(id: "windowSwitcher", title: "Window Switcher", entries: [
            .init(
                "windowSwitcher.enabled",
                "Enable Window Switcher",
                .bool,
                "Takes over Command-Tab and Option-Tab to cycle through window previews."
            ),
            .init(
                "windowSwitcher.commandTab",
                "Command-Tab",
                .choice([
                    .init(value: "activeWorkspace", title: "Active Workspace"),
                    .init(value: "allWorkspaces", title: "All Workspaces"),
                    .init(value: "remembered", title: "Last Used Scope"),
                    .init(value: "disabled", title: "Disabled")
                ]),
                "Workspace scope Command-Tab opens. Disabled leaves Command-Tab to the macOS app switcher."
            ),
            .init(
                "windowSwitcher.optionTab",
                "Option-Tab",
                .choice([
                    .init(value: "activeWorkspace", title: "Active Workspace"),
                    .init(value: "allWorkspaces", title: "All Workspaces"),
                    .init(value: "remembered", title: "Last Used Scope"),
                    .init(value: "disabled", title: "Disabled")
                ]),
                "Workspace scope Option-Tab opens. Disabled leaves Option-Tab alone."
            ),
            .init(
                "windowSwitcher.scope",
                "Remembered Scope",
                .choice([
                    .init(value: "allWorkspaces", title: "All Workspaces"),
                    .init(value: "activeWorkspace", title: "Active Workspace")
                ]),
                "Scope that Last Used Scope opens, saved when you press S or click the scope button."
            ),
            .init(
                "windowSwitcher.showFooter",
                "Show Switcher Footer",
                .bool,
                "Shows the scope button and window count."
            )
        ]),
        IPCSettingsCatalogSection(id: "keyboardModes", title: "Keyboard Modes", entries: [
            .init(
                "keyboardModes.pauseTimeoutSeconds",
                "Pause Timeout",
                .number(),
                "Seconds after which a shortcut pause ends by itself. Unset or 0 keeps the pause until you resume it."
            )
        ]),
        IPCSettingsCatalogSection(id: "gestures", title: "Gestures", entries: [
            .init(
                "gestures.scrollEnabled",
                "Scroll columns",
                .bool,
                "Trackpad column scrolling and modifier plus mouse wheel scrolling along the Niri primary axis."
            ),
            .init(
                "gestures.fingerCount",
                "Scroll columns fingers",
                .int(min: 3, max: 4),
                "Finger count for trackpad column scrolling."
            ),
            .init(
                "gestures.scrollSensitivity",
                "Scroll sensitivity",
                .number(min: 0.1, max: 100.0, step: 0.1),
                "Sensitivity of column scrolling."
            ),
            .init(
                "gestures.trackpadScrollStyle",
                "Trackpad scroll style",
                .choice([
                    .init(value: "snap", title: "Snap to Columns"),
                    .init(value: "momentum", title: "Momentum")
                ]),
                "Snap trackpad scrolling to columns, or scroll freely with momentum."
            ),
            .init(
                "gestures.scrollModifierKey",
                "Mouse scroll modifier",
                .choice([
                    .init(value: "optionShift", title: "Option+Shift (⌥⇧)"),
                    .init(value: "controlShift", title: "Control+Shift (⌃⇧)"),
                    .init(value: "commandShift", title: "Command+Shift (⌘⇧)"),
                    .init(value: "controlOptionShift", title: "Control+Option+Shift (⌃⌥⇧)"),
                    .init(value: "optionCommandShift", title: "Option+Command+Shift (⌥⌘⇧)"),
                    .init(value: "controlCommandShift", title: "Control+Command+Shift (⌃⌘⇧)"),
                    .init(value: "controlOptionCommandShift", title: "Control+Option+Command+Shift (⌃⌥⌘⇧)")
                ]),
                "Modifier held while turning the mouse wheel to scroll columns."
            ),
            .init(
                "gestures.workspaceSwipeEnabled",
                "Switch workspaces",
                .bool,
                "Trackpad swipe switches to the next or previous workspace."
            ),
            .init(
                "gestures.workspaceSwipeFingerCount",
                "Switch workspaces fingers",
                .int(min: 2, max: 4),
                "Finger count for workspace swipes."
            ),
            .init(
                "gestures.workspaceSwipeAxis",
                "Workspace swipe axis",
                .choice([
                    .init(value: "horizontal", title: "Horizontal"),
                    .init(value: "vertical", title: "Vertical")
                ]),
                "Swipe direction for switching workspaces when it doesn't share fingers with column scrolling."
            ),
            .init(
                "gestures.workspaceSwipeEdgeBehavior",
                "Workspace swipe at the ends",
                .choice([
                    .init(value: "cycle", title: "Wrap Around"),
                    .init(value: "none", title: "Stop"),
                    .init(value: "onePast", title: "Open One Empty Workspace")
                ]),
                "What a workspace swipe does past the first or last workspace: wrap around, stop, or open one empty workspace."
            ),
            .init(
                "gestures.overviewGestureEnabled",
                "Overview gesture",
                .bool,
                "Swipe up on the trackpad to open Overview and down to close it."
            ),
            .init(
                "gestures.overviewGestureFingerCount",
                "Overview fingers",
                .int(min: 3, max: 4),
                "Finger count for the Overview gesture."
            ),
            .init(
                "gestures.windowMoveEnabled",
                "Move windows",
                .bool,
                "Drag on the trackpad without clicking to swap the tiled window under the pointer."
            ),
            .init(
                "gestures.windowMoveFingerCount",
                "Move windows fingers",
                .int(min: 2, max: 4),
                "Finger count for the window move gesture."
            ),
            .init(
                "gestures.windowResizeEnabled",
                "Resize windows",
                .bool,
                "Drag on the trackpad without clicking to resize the tiled window under the pointer."
            ),
            .init(
                "gestures.windowResizeFingerCount",
                "Resize windows fingers",
                .int(min: 2, max: 4),
                "Finger count for the window resize gesture."
            ),
            .init(
                "gestures.windowGestureSensitivity",
                "Move & resize sensitivity",
                .number(min: 0.1, max: 5.0, step: 0.1),
                "Sensitivity of the trackpad move and resize gestures. At 1, sweeping the whole trackpad crosses the whole screen."
            ),
            .init(
                "gestures.invertDirection",
                "Invert Direction (Natural)",
                .bool,
                "Inverts the direction of trackpad column scrolling and workspace swipes."
            ),
            .init(
                "gestures.mouseMoveModifierKey",
                "Left Mouse Move Modifier",
                .choice([
                    .init(value: "off", title: "Off"),
                    .init(value: "option", title: "Option"),
                    .init(value: "control", title: "Control"),
                    .init(value: "command", title: "Command"),
                    .init(value: "controlOption", title: "Control+Option"),
                    .init(value: "optionCommand", title: "Option+Command"),
                    .init(value: "controlCommand", title: "Control+Command"),
                    .init(value: "controlOptionCommand", title: "Control+Option+Command")
                ]),
                "Modifier held while left-dragging a tiled window to swap it with, or insert it beside, another tile."
            ),
            .init(
                "gestures.dwindleGroupDragAcrossDisplays",
                "Dwindle Group Across Displays",
                .choice([
                    .init(value: "group", title: "Move Whole Group"),
                    .init(value: "window", title: "Move Dragged Window")
                ]),
                "What a modifier drag of a Dwindle tab group moves when dropped on another display: the whole group or only the dragged window."
            ),
            .init(
                "gestures.mouseResizeModifierKey",
                "Right Mouse Resize Modifier",
                .choice([
                    .init(value: "option", title: "Option"),
                    .init(value: "control", title: "Control"),
                    .init(value: "command", title: "Command"),
                    .init(value: "shift", title: "Shift"),
                    .init(value: "controlOption", title: "Control+Option"),
                    .init(value: "optionCommand", title: "Option+Command"),
                    .init(value: "optionShift", title: "Option+Shift"),
                    .init(value: "controlCommand", title: "Control+Command"),
                    .init(value: "controlShift", title: "Control+Shift"),
                    .init(value: "commandShift", title: "Command+Shift"),
                    .init(value: "controlOptionCommand", title: "Control+Option+Command"),
                    .init(value: "controlOptionShift", title: "Control+Option+Shift"),
                    .init(value: "optionCommandShift", title: "Option+Command+Shift"),
                    .init(value: "controlCommandShift", title: "Control+Command+Shift"),
                    .init(value: "controlOptionCommandShift", title: "Control+Option+Command+Shift")
                ]),
                "Modifier held while right-dragging to resize a tiled window."
            ),
            .init(
                "gestures.adoptNativeMoveAcrossDisplays",
                "Keep Native Moves Across Displays",
                .bool,
                "Keeps a title-bar drag of a tiled window onto another display without a modifier, placing it like a modifier drag."
            ),
            .init(
                "gestures.adoptNativeResize",
                "Keep Native Edge Resizes",
                .bool,
                "Keeps a native edge or corner resize of a tiled window instead of snapping it back."
            ),
            .init(
                "gestures.resizePreviewStyle",
                "Resize Preview",
                .choice([
                    .init(value: "live", title: "Live Resize"),
                    .init(value: "glass", title: "Glass Placeholder"),
                    .init(value: "snapshot", title: "Window Snapshot")
                ]),
                "What mouse, trackpad and Niri keyboard resizing show while the size changes: live frames, a glass placeholder, or a window snapshot."
            )
        ]),
        IPCSettingsCatalogSection(id: "quakeTerminal", title: "Quake Terminal", entries: [
            .init("quakeTerminal.enabled", "Enable Quake Terminal", .bool, "Enables the drop-down Quake terminal."),
            .init(
                "quakeTerminal.provider",
                "Terminal",
                .choice([
                    .init(value: "ghostty", title: "Ghostty"),
                    .init(value: "kitty", title: "Kitty"),
                    .init(value: "foot", title: "foot")
                ]),
                "Terminal that provides the Quake terminal: embedded Ghostty, Kitty's quick-access terminal, or foot."
            ),
            .init(
                "quakeTerminal.position",
                "Position",
                .choice([
                    .init(value: "top", title: "Top"),
                    .init(value: "bottom", title: "Bottom"),
                    .init(value: "left", title: "Left"),
                    .init(value: "right", title: "Right"),
                    .init(value: "center", title: "Center")
                ]),
                "Where the Ghostty terminal appears. Edge positions slide in; Center fades in place."
            ),
            .init(
                "quakeTerminal.monitorMode",
                "Show On",
                .choice([
                    .init(value: "mouseCursor", title: "Mouse Cursor's Monitor"),
                    .init(value: "focusedWindow", title: "Focused Window's Monitor"),
                    .init(value: "mainMonitor", title: "Main Monitor")
                ]),
                "Which monitor the Ghostty terminal appears on."
            ),
            .init(
                "quakeTerminal.widthPercent",
                "Width",
                .number(min: 10.0, max: 100.0, step: 5.0),
                "Ghostty terminal width as a percentage of the monitor's available screen area."
            ),
            .init(
                "quakeTerminal.heightPercent",
                "Height",
                .number(min: 10.0, max: 100.0, step: 5.0),
                "Ghostty terminal height as a percentage of the monitor's available screen area."
            ),
            .init(
                "quakeTerminal.backgroundEffect",
                "Background Effect",
                .choice([
                    .init(value: "standardBlur", title: "Standard Blur"),
                    .init(value: "glassRegular", title: "Regular Glass"),
                    .init(value: "glassClear", title: "Clear Glass")
                ]),
                "Background material of the Ghostty terminal."
            ),
            .init(
                "quakeTerminal.opacity",
                "Quake Background Opacity",
                .number(min: 0.0, max: 1.0, step: 0.05),
                "Background opacity of the Ghostty terminal."
            ),
            .init(
                "quakeTerminal.backgroundBlurRadius",
                "Background Blur",
                .int(min: 0, max: 100, step: 5),
                "Extra background blur radius of the Ghostty terminal; 0 turns it off."
            ),
            .init(
                "quakeTerminal.animationDuration",
                "Animation Duration",
                .number(min: 0.0, max: 1.0, step: 0.1),
                "Show and hide animation duration in seconds."
            ),
            .init(
                "quakeTerminal.autoHide",
                "Auto-hide on Focus Loss",
                .bool,
                "Hides the Ghostty terminal when it loses focus."
            ),
            .init(
                "quakeTerminal.kitty.placement.position",
                "Kitty Position",
                .choice([
                    .init(value: "top", title: "Top"),
                    .init(value: "bottom", title: "Bottom"),
                    .init(value: "left", title: "Left"),
                    .init(value: "right", title: "Right"),
                    .init(value: "center", title: "Center")
                ]),
                "Kitty panel position, used while OmniWM overrides Kitty's placement."
            ),
            .init(
                "quakeTerminal.kitty.placement.widthPercent",
                "Kitty Width",
                .number(min: 10.0, max: 100.0, step: 5.0),
                "Kitty panel width as a percentage of the monitor's available screen area, used while OmniWM overrides Kitty's placement."
            ),
            .init(
                "quakeTerminal.kitty.placement.heightPercent",
                "Kitty Height",
                .number(min: 10.0, max: 100.0, step: 5.0),
                "Kitty panel height as a percentage of the monitor's available screen area, used while OmniWM overrides Kitty's placement."
            ),
            .init(
                "quakeTerminal.kitty.autoHide",
                "Kitty Auto-hide on Focus Loss",
                .bool,
                "Hides the Kitty panel when it loses focus. Unset uses Kitty's own configuration."
            ),
            .init(
                "quakeTerminal.kitty.opacity",
                "Kitty Background Opacity",
                .number(min: 0.0, max: 1.0, step: 0.05),
                "Kitty panel background opacity. Unset uses Kitty's own configuration."
            )
        ]),
        IPCSettingsCatalogSection(id: "clipboard", title: "Clipboard", entries: [
            .init("clipboard.historyEnabled", "Enable Clipboard History", .bool, "Captures clipboard history."),
            .init("clipboard.maxItems", "Max Items", .int(), "Maximum number of unpinned clipboard history entries."),
            .init(
                "clipboard.maxItemBytes",
                "Max Item Bytes",
                .int(),
                "Maximum size of a single clipboard history entry in bytes."
            ),
            .init(
                "clipboard.maxTotalBytes",
                "Max Total Bytes",
                .int(),
                "Maximum total size of clipboard history in bytes, including pins."
            )
        ]),
        IPCSettingsCatalogSection(id: "launcher", title: "Launcher", entries: [
            .init(
                "launcher.shell",
                "Shell",
                .choice([
                    .init(value: "system", title: "System Login Shell"),
                    .init(value: "nushell", title: "Nushell"),
                    .init(value: "fish", title: "fish"),
                    .init(value: "zsh", title: "zsh"),
                    .init(value: "bash", title: "Bash")
                ]),
                "Shell for saved entries and CLI tools unless an entry overrides it."
            ),
            .init(
                "launcher.shellExecutable",
                "Shell Executable",
                .string,
                "Explicit path to the selected shell. Empty uses the selected shell from PATH."
            ),
            .init(
                "launcher.terminal",
                "Terminal",
                .choice([
                    .init(value: "builtIn", title: "Built-in Quake Terminal"),
                    .init(value: "terminal", title: "Terminal"),
                    .init(value: "ghostty", title: "Ghostty"),
                    .init(value: "iterm", title: "iTerm2"),
                    .init(value: "kitty", title: "kitty")
                ]),
                "Terminal that commands open in unless an entry overrides it. The built-in option requires the Ghostty Quake Terminal."
            )
        ]),
        IPCSettingsCatalogSection(id: "shellPermissions", title: "Network & Permissions", entries: [
            .init(
                "shellPermissions.services.weather",
                "Weather",
                .bool,
                "Lets the weather widget send the city or coordinates you set to its weather service."
            ),
            .init(
                "shellPermissions.services.lyrics",
                "Lyrics",
                .bool,
                "Lets the lyrics widget send the playing track's title, artist, album, and length to its lyrics service."
            )
        ])
    ]
}
