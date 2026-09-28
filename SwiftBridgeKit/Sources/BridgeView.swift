//
//  BridgeView.swift
//  SwiftBridgeKit
//
//  桥视图协议：UIKit 侧唯一需要遵守的约定。
//
//  一个组件作者需要实现的东西被压缩到三件：
//    - onIntent : 往上报告用户意图
//    - apply    : 往下接收数据快照
//    - teardown : 尽力清理（可空实现）
//  另有第四件「可选」：
//    - onRequestLayout : 尺寸回流通道，由 Coordinator 注入，需要异步比例时才用
//

import UIKit

/// 桥视图协议：UIKit 组件唯一需要遵守的约定。
///
/// 组件作者只需实现三件事：用 onIntent 上报用户意图、用 apply 接收并渲染数据快照、
/// 用 teardown 做尽力清理；尺寸回流通道 onRequestLayout 可选（协议扩展提供空实现，
/// 用在需要异步比例回流的组件上）。
@MainActor
public protocol BridgeView: UIView {

    /// 从 SwiftUI 侧流入桥视图的数据快照类型。
    associatedtype State: BridgeState
    /// 上报给业务方、需要被响应的意图类型。
    associatedtype Intent: BridgeIntent

    /// 向上报告的通道。由 Coordinator 在 attach 时注入。
    var onIntent: ((Intent) -> Void)? { get set }

    /// 「请求一次重新布局」的通道（尺寸回流用）。由 Coordinator 在 attach 时注入。
    ///
    /// 组件在拿到异步比例等需要回流的信号时调用它，框架会请求 SwiftUI 重新布局，
    /// 让 sizeThatFits 用更新后的内容信息重新计算尺寸。
    /// 纯展示型组件无需实现：协议扩展提供空实现。
    var onRequestLayout: (() -> Void)? { get set }

    /// 每桥主题覆盖（phase 1 仅颜色）。由 Coordinator 在 apply 时注入；
    /// 组件在 apply 内用 `resolvedTheme()`（= 本属性 ?? 全局 current）解析颜色。
    /// 纯展示、不关心换肤的组件可完全不碰它（协议扩展提供空实现）。
    var theme: (any BridgeTheme)? { get set }

    /// 把一份 state 快照映射到视图上。
    ///
    /// ⚠️ 只做「差异映射」，不要无条件全量重建。
    ///     Coordinator 已经做了值比较早退，这里再做增量写入即可。
    /// ⚠️ 本方法在抑制窗口内被调用，**不要在其中调用 onIntent**。
    func apply(_ state: State)

    /// 尽力清理：停播放、断 layer、释放大缓存。
    /// 必须幂等（可能被 dismantle 与 deinit 路径都触发）。
    func teardown()
}

/// 桥视图协议的默认实现（纯展示型组件可直接复用）。
public extension BridgeView {
    /// 默认空实现，纯展示型组件不用写。
    func teardown() {}

    /// 默认空实现：不注入尺寸回流通道。
    var onRequestLayout: (() -> Void)? {
        get { nil }
        set {}
    }

    /// 默认空实现：不注入主题覆盖（组件回落全局主题）。
    var theme: (any BridgeTheme)? {
        get { nil }
        set {}
    }
}
