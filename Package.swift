// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ABreak",
    platforms: [.macOS("14.2")],
    targets: [
        .target(name: "ABreakCore"),
        .executableTarget(
            name: "ABreak",
            dependencies: ["ABreakCore"],
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreMediaIO"),
                .linkedFramework("IOKit"),
            ]
        ),
        .testTarget(name: "ABreakCoreTests", dependencies: ["ABreakCore"]),
    ]
)
