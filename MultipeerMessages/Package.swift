// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MultipeerMessages",
    platforms: [
        .macOS(.v11),
        .tvOS(.v14),
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "MultipeerMessages",
            targets: ["MultipeerMessages"])
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "MultipeerMessages",
            dependencies: [])
    ]
)
