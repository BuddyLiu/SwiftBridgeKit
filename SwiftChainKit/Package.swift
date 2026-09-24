// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftChainKit",
    platforms: [
        // 对齐组件包基线：iOS 15（UIButton 尺寸守卫等 API 均已覆盖）。
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SwiftChainKit",
            targets: ["SwiftChainKit"]
        )
    ],
    targets: [
        .target(
            name: "SwiftChainKit",
            path: "Sources"
        ),
        .testTarget(
            name: "SwiftChainKitTests",
            dependencies: ["SwiftChainKit"],
            path: "Tests"
        )
    ]
)