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
        .package(url: "git@github.com:machineko/SwiftyXPC", from: "0.6.0"),
        .package(url: "git@github.com:swiftlang/swift-syntax.git", exact: "601.0.1"),
    ],
    targets: [
        .macro(
            name: "xpcMacrosMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(
            name: "xpcMacros", 
            dependencies: ["xpcMacrosMacros"]
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
            dependencies: ["xpcUtils"]
        )
    ]
)

// swift build -c release --enable-experimental-prebuilts
// or
// defaults write com.apple.dt.Xcode IDEPackageEnablePrebuilts YES

