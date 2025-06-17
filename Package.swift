// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "xpcUtils",
    platforms: [.macOS(.v11)],
    products: [
        .library(
            name: "xpcUtils",
            targets: ["xpcUtils"]
        ),
        .library(
            name: "xpcMacros",
            targets: ["xpcMacros"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0"),
        .package(url: "https://github.com/machineko/SwiftyXPC", branch: "main")
    ],
    targets: [
        .macro(
            name: "xpcMacrosMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "xpcMacros", 
            dependencies: ["xpcMacrosMacros"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "xpcUtils",
            dependencies: [
                .product(name: "SwiftyXPC", package: "SwiftyXPC"),
                "xpcMacros"
            ]
        ),
        .testTarget(
            name: "xpcUtilsTests",
            dependencies: ["xpcUtils", "xpcMacros"]
        )
    ]
)
