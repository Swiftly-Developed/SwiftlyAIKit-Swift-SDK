// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftlyAIKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .watchOS(.v9),
        .tvOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        // Core library - works on all platforms (server + device)
        .library(
            name: "SwiftlyAIKit",
            targets: ["SwiftlyAIKit"]
        ),
        // Vapor integration - server-side only
        .library(
            name: "SwiftlyAIKitVapor",
            targets: ["SwiftlyAIKitVapor"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.99.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.19.0"),
    ],
    targets: [
        // Core framework - platform-agnostic (no Vapor dependency)
        .target(
            name: "SwiftlyAIKit",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),
        // Vapor extensions - depends on core + Vapor
        .target(
            name: "SwiftlyAIKitVapor",
            dependencies: [
                "SwiftlyAIKit",
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        // Tests - test core functionality
        .testTarget(
            name: "SwiftlyAIKitTests",
            dependencies: ["SwiftlyAIKit"]
        ),
    ]
)
