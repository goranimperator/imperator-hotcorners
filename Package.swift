// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "ImperatorHotCorners",
    // Brandbook "Toolchain and SDK": the string form stamps minos 26.0 / sdk 26.0,
    // and the sdk field decides which generation of AppKit controls gets drawn.
    platforms: [.macOS("26.0")],
    targets: [
        .target(
            name: "HotCornersCore",
            path: "Sources/HotCornersCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "ImperatorHotCorners",
            dependencies: ["HotCornersCore"],
            path: "Sources/ImperatorHotCorners",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "HotCornersCoreTests",
            dependencies: ["HotCornersCore"],
            path: "Tests/HotCornersCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
