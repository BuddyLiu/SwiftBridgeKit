// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftBridgeKit",
    platforms: [
        // 基线取 iOS 15：桥的核心设施（抑制 / 生命周期 / 差异映射）都不依赖新 API。
        //
        // 尺寸自适应通道用的是 UIViewRepresentable.sizeThatFits（iOS 16+），
        // 相关入口已用 @available(iOS 16.0, *) 守卫：
        //   - BridgeRepresentable.sizeThatFits
        //   - ProposedSizeTranslator.resolveWidth
        // 即：iOS 15 上照常可用（尺寸退化为由组件 intrinsicContentSize 自持），
        //     iOS 16+ 自动获得「参与 SwiftUI 布局系统」的能力。
        //
        // 若你的项目基线就是 iOS 16+，改成 .iOS(.v16) 并去掉守卫即可。
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SwiftBridgeKit",
            targets: ["SwiftBridgeKit"]
        )
    ],
    targets: [
        .target(
            name: "SwiftBridgeKit",
            path: "Sources"
        ),
        .testTarget(
            name: "SwiftBridgeKitTests",
            dependencies: ["SwiftBridgeKit"],
            path: "Tests"
        )
    ]
)
