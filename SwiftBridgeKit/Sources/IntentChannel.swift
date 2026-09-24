//
//  IntentChannel.swift
//  SwiftBridgeKit
//
//  设施一：契约层。
//
//  设计约束（对应 05_通用适配层设计要点.md §1.1）：
//    1. 本文件**不 import UIKit**，也不 import SwiftUI。
//    2. State 只描述"数据"，Intent 只描述"用户可理解的意图"。
//    3. 严禁在 Intent 里放 didLayout / didScroll / frameChanged 这类内部副产物。
//       —— 那是桥的实现细节，漏到契约层会污染业务、并且自己造出循环更新路径。
//

import Foundation

// MARK: - 数据：SwiftUI → UIKit（单向流入）

/// 从 SwiftUI 侧流入桥视图的数据快照。
///
/// 必须 `Equatable`：Coordinator 依赖值比较做「早退」，
/// 这是成本极低、收益极大的一道防线（见 BridgeCoordinator.apply）。
public protocol BridgeState: Equatable {}

// MARK: - 意图：UIKit → 业务（单向上报）

/// 用户在桥视图里做出的、业务方需要响应的一次意图。
///
/// 判据（05 §3.4）：如果一个人无法向产品经理描述这个事件，它就不该出现在这里。
public protocol BridgeIntent: Equatable {}

// MARK: - 空实现便利类型

/// 不承载任何数据、也不需要上报意图的桥（如纯展示型组件）可直接用这两个占位。
public struct EmptyState: BridgeState {
    /// 创建一个空状态。
    public init() {}
}

/// 无需上报任何意图的信号量占位。
///
/// 纯展示型组件可直接使用本类型作为 Intent。
public enum NoIntent: BridgeIntent {
    /// 唯一的空意图，表示「没有任何意图」。
    case none
}
