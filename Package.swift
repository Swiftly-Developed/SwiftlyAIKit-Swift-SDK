// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftlyAIKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftlyAIKit",
            targets: ["SwiftlyAIKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.99.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.19.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftlyAIKit",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),
        .testTarget(
            name: "SwiftlyAIKitTests",
            dependencies: ["SwiftlyAIKit"]
        ),
    ]
)
