// swift-tools-version: 6.5
import Foundation
import PackageDescription

// Fork: GhosttyKit is not linked, so the Quake terminal files that need it are
// left out of the build, along with their tests.
let ghosttyQuakeTerminalSources = [
    "QuakeTerminal/GhosttyAppCallbackContext.swift",
    "QuakeTerminal/GhosttyClipboard.swift",
    "QuakeTerminal/GhosttySurfaceSizing.swift",
    "QuakeTerminal/GhosttySurfaceTextInput.swift",
    "QuakeTerminal/GhosttySurfaceView.swift",
    "QuakeTerminal/QuakeClipboardAlert.swift",
    "QuakeTerminal/QuakeClipboardPromptCoordinator.swift",
    "QuakeTerminal/QuakeGhosttyConfig.swift",
    "QuakeTerminal/QuakeGhosttyInputBridge.swift",
    "QuakeTerminal/QuakeGhosttyRuntime.swift",
    "QuakeTerminal/QuakeSplitContainer.swift",
    "QuakeTerminal/QuakeTerminalAnimator.swift",
    "QuakeTerminal/QuakeTerminalBackground.swift",
    "QuakeTerminal/QuakeTerminalController.swift",
    "QuakeTerminal/QuakeTerminalTab.swift",
    "QuakeTerminal/QuakeTerminalTabs.swift",
    "QuakeTerminal/QuakeTerminalURLHandler.swift",
    "QuakeTerminal/QuakeWindowInteraction.swift",
    "QuakeTerminal/SplitNode.swift",
]

let ghosttyQuakeTerminalTests = [
    "GhosttyClipboardMIMERequestsTests.swift",
    "GhosttyNumericLocaleTests.swift",
    "GhosttySurfaceDisplayTests.swift",
    "GhosttySurfaceOcclusionTests.swift",
    "GhosttySurfaceSizingTests.swift",
    "QuakeClipboardPromptTests.swift",
    "QuakeGhosttyAppearanceTests.swift",
    "QuakeGhosttyKeyEquivalentTests.swift",
    "QuakeGhosttyRuntimeTests.swift",
    "QuakeTerminalBackgroundTests.swift",
    "QuakeTerminalKeyMappingTests.swift",
    "QuakeTerminalScreenSelectionTests.swift",
    "QuakeTerminalURLHandlerTests.swift",
    "QuakeWindowInteractionTests.swift",
    "SplitNodeGeometryTests.swift",
]

let package = Package(
    name: "OmniWM",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "OmniWM",
            targets: ["OmniWMApp"]
        ),
        .executable(
            name: "omniwmctl",
            targets: ["OmniWMCtl"]
        ),
        .library(
            name: "OmniWMNowPlaying",
            type: .dynamic,
            targets: ["OmniWMNowPlaying"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/mattt/swift-toml.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "OmniWMIPC",
            path: "Sources/OmniWMIPC",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "OmniWMLayerCorners",
            path: "Sources/OmniWMLayerCorners",
            cSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "OmniWMAudioTap",
            path: "Sources/OmniWMAudioTap",
            cSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "OmniWMNowPlaying",
            path: "Sources/OmniWMNowPlaying",
            cSettings: [
                .treatAllWarnings(as: .error)
            ],
            linkerSettings: [
                .linkedFramework("Foundation")
            ]
        ),
        .target(
            name: "OmniWMLauncherSPI",
            path: "Sources/OmniWMLauncherSPI",
            cSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "OmniWMLuau",
            path: "Sources/OmniWMLuau",
            exclude: ["LICENSE.txt", "lua_LICENSE.txt", "VERSION", "Bytecode/src/BytecodeGraph.cpp"],
            cxxSettings: [
                .headerSearchPath("Common/include"),
                .headerSearchPath("Ast/include"),
                .headerSearchPath("Bytecode/include"),
                .headerSearchPath("Compiler/include"),
                .headerSearchPath("VM/include"),
                .headerSearchPath("VM/src"),
                .treatAllWarnings(as: .error),
                .treatWarning("unused-command-line-argument", as: .warning)
            ]
        ),
        .target(
            name: "OmniWMScriptHost",
            dependencies: ["OmniWMLuau"],
            path: "Sources/OmniWMScriptHost",
            cxxSettings: [
                .treatAllWarnings(as: .error),
                .treatWarning("unused-command-line-argument", as: .warning)
            ]
        ),
        .target(
            name: "OmniWMMaterialColor",
            path: "Sources/OmniWMMaterialColor",
            cxxSettings: [
                .headerSearchPath("."),
                .treatAllWarnings(as: .error),
                .treatWarning("unused-command-line-argument", as: .warning)
            ]
        ),
        .target(
            name: "OmniWMShellCore",
            path: "Sources/OmniWMShellCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .treatAllWarnings(as: .error)
            ]
        ),
        .target(
            name: "OmniWM",
            dependencies: [
                "OmniWMIPC",
                "OmniWMAudioTap",
                "OmniWMLayerCorners",
                "OmniWMLauncherSPI",
                "OmniWMMaterialColor",
                "OmniWMScriptHost",
                "OmniWMShellCore",
                .product(name: "TOML", package: "swift-toml")
            ],
            path: "Sources/OmniWM",
            // Fork: the Ghostty-backed Quake terminal is compiled out; see
            // QuakeTerminal/QuakeTerminalDisabled.swift for the stand-in.
            exclude: ghosttyQuakeTerminalSources,
            resources: [
                .process("Resources"),
                .copy("Core/IssueReporter/Prompts"),
                .copy("ShellDefault"),
                .copy("ShellStyles"),
                .copy("Fonts")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .treatAllWarnings(as: .error),
                .interoperabilityMode(.C),
                .unsafeFlags([
                    "-Xfrontend", "-disable-autolink-framework", "-Xfrontend", "FoundationModels",
                    "-Xfrontend", "-disable-round-trip-debug-types"
                ])
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore"),
                .linkedLibrary("z"),
                .linkedLibrary("c++"),
                .unsafeFlags(["-F/System/Library/PrivateFrameworks", "-framework", "SkyLight"]),
                .unsafeFlags(["-weak_framework", "FoundationModels"])
            ]
        ),
        .executableTarget(
            name: "OmniWMApp",
            dependencies: ["OmniWM"],
            path: "Sources/OmniWMApp",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .treatAllWarnings(as: .error)
            ]
        ),
        .executableTarget(
            name: "OmniWMCtl",
            dependencies: ["OmniWMIPC"],
            path: "Sources/OmniWMCtl",
            resources: [
                .embedInCode("Completions/completion.zsh"),
                .embedInCode("Completions/completion.bash"),
                .embedInCode("Completions/completion.fish"),
                .embedInCode("Completions/completion.nu")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .treatAllWarnings(as: .error)
            ]
        ),
        .testTarget(
            name: "OmniWMTests",
            dependencies: [
                "OmniWM", "OmniWMAudioTap", "OmniWMCtl", "OmniWMLayerCorners", "OmniWMMaterialColor",
                "OmniWMScriptHost",
                "OmniWMShellCore"
            ],
            path: "Tests/OmniWMTests",
            exclude: ghosttyQuakeTerminalTests,
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .treatAllWarnings(as: .error)
            ]
        )
    ],
    cxxLanguageStandard: .cxx17
)
