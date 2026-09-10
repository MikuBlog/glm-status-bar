// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GLMStatusBar",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "GLMStatusBar",
            path: "Sources/GLMStatusBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "GLMStatusBarTests",
            dependencies: ["GLMStatusBar"],
            path: "Tests/GLMStatusBarTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
