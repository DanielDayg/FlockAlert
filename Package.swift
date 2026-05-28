// swift-tools-version: 5.9
// This Package.swift is for reference only.
// Open FlockAlert.xcodeproj in Xcode to build.
// Create a new iOS App project in Xcode, add these source files,
// and configure the targets and capabilities described in README.md.

import PackageDescription

let package = Package(
    name: "FlockAlert",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "FlockAlert", targets: ["FlockAlert"])
    ],
    targets: [
        .target(
            name: "FlockAlert",
            path: "FlockAlert",
            resources: [
                .process("Resources/SeedCameras.json")
            ]
        )
    ]
)
