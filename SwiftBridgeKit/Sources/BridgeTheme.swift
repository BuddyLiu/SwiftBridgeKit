//
//  BridgeTheme.swift
//  SwiftBridgeKit
//
//  桥接主题契约（设施：主题可注入）。
//
//  为什么 refine Hashable 而非空 marker：
//    BridgeCoordinator 的值比较早退需要判断「主题是否变化」。
//    对两个 `any BridgeTheme` **不能**直接用 `==` —— Swift 6 下
//    'type "any P" cannot conform to "Equatable"'（本机 Swift 6.3 已实测），
//    必须经 `AnyHashable(x) == AnyHashable(y)` 类型擦除比较；
//    故协议 refine `Hashable`（任何值主题带差异就够，CID 不必）。
//
//  为什么不标 @MainActor：
//    主题在 Coordinator（@MainActor）与组件 apply（@MainActor）之间流动，
//    加上全局 `ComponentTheme.current` 自己用 `@MainActor static var` 隔离；
//    协议本身不做演员隔离，能让实现侧（组件的纯值 struct）保持无标注、
//    synthesized Hashable/Equatable 直接可用，零并发摩擦。
//

import Foundation

/// 桥接主题契约（phase 1 只承载颜色）。
///
/// 由组件包（如 SwiftBridgeComponents 的 ComponentTheme）实现；
/// BridgeCoordinator 在 apply 时把它注入桥视图，组件在 apply 内用
/// `resolvedTheme()`（= 桥自带 theme ?? 全局 current）解析颜色。
/// 纯展示、不关心换肤的组件可以完全不碰它。
public protocol BridgeTheme: Hashable {}