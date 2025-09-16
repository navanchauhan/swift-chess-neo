// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-chess-neo",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "SwiftChessCore",
            targets: ["SwiftChessCore"]),
        .library(
            name: "SwiftChessUI",
            targets: ["SwiftChessUI"]),
        .executable(
            name: "BoardDemoApp",
            targets: ["BoardDemoApp"]),
    ],
    targets: [
        .target(
            name: "SwiftChessCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]),
        .target(
            name: "SwiftChessUI",
            dependencies: ["SwiftChessCore"]),
        .executableTarget(
            name: "BoardDemoApp",
            dependencies: ["SwiftChessCore", "SwiftChessUI"],
            path: "Examples/BoardDemoApp"),
        .testTarget(
            name: "SwiftChessCoreTests",
            dependencies: ["SwiftChessCore", "SwiftChessUI"]),
    ]
)
