// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SnapLingo",
    platforms: [
        .macOS(.v12) // Downgraded to v12 for compatibility
    ],
    products: [
        .executable(name: "SnapLingo", targets: ["SnapLingo"])
    ],
    dependencies: [
        // No external dependencies for now to ensure compatibility
    ],
    targets: [
        .executableTarget(
            name: "SnapLingo",
            dependencies: [],
            resources: []
        ),
        .testTarget(
            name: "SnapLingoTests",
            dependencies: ["SnapLingo"]
        ),
    ]
)
