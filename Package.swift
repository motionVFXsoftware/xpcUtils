// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "xpcUtils",
    platforms: [.macOS(.v11)],
    products: [
        .library(
            name: "xpcUtils",
            targets: ["xpcUtils"]),
        .library(
            name: "xpcMacros",
            targets: ["xpcMacros"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0-latest"),
        .package(url: "https://github.com/machineko/SwiftyXPC", branch: "main"),

    ],
    targets: [
        .macro(
            name: "xpcMacrosMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(name: "xpcMacros", dependencies: ["xpcMacrosMacros"]),

        .target(
            name: "xpcUtils",
            dependencies: [
                .product(name: "SwiftyXPC", package: "SwiftyXPC"), "xpcMacros"
            ]
        ),
        
        .testTarget(
            name: "xpcUtilsTests",
            dependencies: ["xpcUtils"]
        ),
    ]
)
