// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "xpcUtils",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "xpcUtils", targets: ["xpcUtils"])
    ],
    dependencies: [
        .package(url: "https://github.com/machineko/SwiftyXPC", branch: "main")
    ],
    targets: [
        .target(
            name: "xpcUtils",
            dependencies: [
                .product(name: "SwiftyXPC", package: "SwiftyXPC")
            ]
        ),
        .testTarget(
            name: "xpcUtilsTests",
            dependencies: ["xpcUtils"]
        )
    ]
)
