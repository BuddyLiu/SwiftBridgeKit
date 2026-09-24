// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftBridgeComponents",
    platforms: [
        // 与框架包基线一致：iOS 15。
        // 五个组件用到的 API（SF Symbols、UIActivityIndicatorView(.medium)、UIButton）
        // 均 iOS 15 可用；不使用 UIButton.Configuration 则无需 iOS 15 尺寸守卫。
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SwiftBridgeComponents",
            targets: ["SwiftBridgeComponents"]
        )
    ],
    dependencies: [
        // 本地路径依赖：demo 工程用 relativePath = ../SwiftBridgeComponents 指到本目录，
        // 本包自己指到兄弟目录 ../SwiftBridgeKit。
        .package(path: "../SwiftBridgeKit"),
        // 点语法链式配置 DSL：视图创建块的「实例化 + 逐属性赋值」换成 .chain 设置
        // （见 ../SwiftChainKit —— 零依赖、纯 UIKit，可独立开源）。
        .package(path: "../SwiftChainKit"),
        // 约束 DSL：vendored SnapKit 5.6.0（见 ../Vendor/SnapKit —— 本地路径依赖，
        // 离线可解析；若日后出网可用，可回退成 .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.6.0")）。
        .package(path: "../Vendor/SnapKit")
    ],
    targets: [
        .target(
            name: "SwiftBridgeComponents",
            dependencies: [
                .product(name: "SwiftBridgeKit", package: "SwiftBridgeKit"),
                .product(name: "SwiftChainKit", package: "SwiftChainKit"),
                .product(name: "SnapKit", package: "SnapKit")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "SwiftBridgeComponentsTests",
            dependencies: ["SwiftBridgeComponents"],
            path: "Tests"
        )
    ]
)