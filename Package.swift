// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-chess-neo",
    products: [
        .library(
            name: "SwiftChessCore",
            targets: ["SwiftChessCore"]),
        .library(
            name: "SwiftChessUI",
            targets: ["SwiftChessUI"]),
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
        .testTarget(
            name: "SwiftChessCoreTests",
            dependencies: ["SwiftChessCore"]),
    ]
)
