// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CaptureLingo",
    platforms: [
        .macOS(.v12) // Downgraded to v12 for compatibility
    ],
    products: [
        .executable(name: "CaptureLingo", targets: ["CaptureLingo"])
    ],
    dependencies: [
        // No external dependencies for now to ensure compatibility
    ],
    targets: [
        .executableTarget(
            name: "CaptureLingo",
            dependencies: [],
            resources: []
        ),
        .testTarget(
            name: "CaptureLingoTests",
            dependencies: ["CaptureLingo"]
        ),
    ]
)
