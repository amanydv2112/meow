// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "meow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "meow", targets: ["meow"]),
        .library(name: "MeowCore", targets: ["MeowCore"])
    ],
    targets: [
        .target(
            name: "CSQLite",
            path: "Sources/CSQLite",
            publicHeadersPath: "include"
        ),
        .target(
            name: "MeowCore",
            dependencies: ["CSQLite"],
            path: "Sources/MeowCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        // Lowercase so the built binary and the .app bundle are named "meow".
        // Nothing imports this target, so the module name never appears in code.
        .executableTarget(
            name: "meow",
            dependencies: ["MeowCore"],
            path: "Sources/Meow"
        ),
        .executableTarget(
            name: "MeowIconGen",
            dependencies: ["MeowCore"],
            path: "Tools/MeowIconGen"
        ),
        .executableTarget(
            name: "MeowCoreSmokeTests",
            dependencies: ["MeowCore"],
            path: "Tests/MeowCoreSmokeTests"
        ),
        .executableTarget(
            name: "MeowRecorderSmokeTests",
            dependencies: ["MeowCore"],
            path: "Tests/MeowRecorderSmokeTests"
        )
    ]
)
