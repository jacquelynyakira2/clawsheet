// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeCodeHelper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClaudeCodeHelper", targets: ["ClaudeCodeHelperApp"]),
        .library(name: "ClaudeCodeHelperCore", targets: ["ClaudeCodeHelperCore"])
    ],
    targets: [
        .target(
            name: "ClaudeCodeHelperCore",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "ClaudeCodeHelperApp",
            dependencies: ["ClaudeCodeHelperCore"]
        ),
        .testTarget(
            name: "ClaudeCodeHelperCoreTests",
            dependencies: ["ClaudeCodeHelperCore"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
