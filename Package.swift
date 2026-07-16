// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftlyAIKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .watchOS(.v9),
        .tvOS(.v16)
    ],
    products: [
        .library(
            name: "SwiftlyAIKit",
            targets: ["SwiftlyAIKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.19.0"),
    ],
    targets: [
        .target(
            name: "SwiftlyAIKit",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),
        .testTarget(
            name: "SwiftlyAIKitTests",
            dependencies: ["SwiftlyAIKit"]
        ),
    ]
)
