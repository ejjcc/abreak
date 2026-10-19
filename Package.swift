// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Stretch",
    platforms: [.macOS("14.2")],
    targets: [
        .target(name: "StretchCore"),
        .executableTarget(
            name: "Stretch",
            dependencies: ["StretchCore"],
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreMediaIO"),
                .linkedFramework("IOKit"),
            ]
        ),
        .testTarget(name: "StretchCoreTests", dependencies: ["StretchCore"]),
    ]
)
