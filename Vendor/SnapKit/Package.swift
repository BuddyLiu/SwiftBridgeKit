// swift-tools-version: 5.9
//
//  Vendored SnapKit 5.6.0 —— 本地路径依赖（离线 vendoring）。
//
//  本环境出网被拒（GitHub 不可达），SPM 无法为远程 URL 解析依赖，
//  故把 SnapKit 源码随仓库 vendoring：依赖方声明 `.package(path: "../Vendor/SnapKit")` 即可，
//  与上游 Package.swift 内容一致，不涉及任何改动。
//
//  上游: https://github.com/SnapKit/SnapKit (MIT)
//  vendoring 版本: 5.6.0（源码来自本地 Pods 缓存，`Pods/SnapKit/Sources`）
//

import PackageDescription

let package = Package(
    name: "SnapKit",
    platforms: [
        // 与上游一致：iOS 10+。消费方基线（iOS 15）会进一步收紧。
        .iOS(.v10),
        .macOS(.v10_12),
        .tvOS(.v10),
        .watchOS(.v3),
    ],
    products: [
        .library(
            name: "SnapKit",
            targets: ["SnapKit"]
        )
    ],
    targets: [
        .target(
            name: "SnapKit",
            path: "Sources"
        )
    ]
)