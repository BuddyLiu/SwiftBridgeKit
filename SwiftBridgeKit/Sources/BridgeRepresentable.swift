//
//  BridgeRepresentable.swift
//  SwiftBridgeKit
//
//  框架级：UIViewRepresentable 模板 + 声明式外壳。
//
//  这一层是整个包里唯一 import SwiftUI 的「桥」文件。
//  业务侧只需要见到 BridgeHost，不需要知道 Representable 的存在。
//
//  ⚠️ 泛型参数不要命名为 View / State / Intent 等与 SwiftUI、Swift 标准库同名的标识符。
//     曾踩坑：泛型参数名 `View` 会遮蔽 SwiftUI 的 `View` 协议，
//     导致 `struct X<View: BridgeView>: View` 报
//     "Inheritance from non-protocol type 'View'"，
//     `some View` 报 "A 'some' type must specify only ..."。
//     故这里统一用 `Bridge` 作为泛型参数名。
//

import SwiftUI

// MARK: - Representable 模板（框架级，组件作者不用改）

/// UIViewRepresentable 模板：把一个遵守 BridgeView 的 UIKit 组件桥接进 SwiftUI。
///
/// 框架内部使用的底层实现：归拢了 makeCoordinator / makeUIView / updateUIView /
/// dismantleUIView 的标准写法，以及「比例异步就绪 → 请求 SwiftUI 重布局」的闭环。
/// 业务侧无需直接接触本类型，顶层入口是 BridgeHost。
public struct BridgeRepresentable<Bridge: BridgeView>: UIViewRepresentable {

    /// 本桥使用的协调器类型。
    public typealias Coordinator = BridgeCoordinator<Bridge>

    // 最新数据快照。
    private let state: Bridge.State
    // 桥视图工厂，每次装配（makeUIView）调用一次。
    private let makeView: () -> Bridge
    // 意图上报通道的最终去向。
    private let onIntent: (Bridge.Intent) -> Void

    /// 可选：提供内容比例，用于 SwiftUI 侧布局计算。
    /// 返回 nil 表示比例尚未就绪（此时不参与布局，等就绪后回流）。
    private let ratioProvider: ((Bridge) -> CGFloat?)?

    /// 尺寸变化（如比例异步就绪）时，请求 SwiftUI 重新执行一次布局。
    /// 框架内部把 RatioResolver 的「布局回流」接到 SwiftUI 侧（见 makeUIView）。
    private let requestLayout: () -> Void

    /// 创建桥接器。
    ///
    /// - Parameters:
    ///   - state: 初始数据快照。
    ///   - makeView: 创建桥视图的闭包，每次装配调用一次。
    ///   - onIntent: 意图上报的最终去向。
    ///   - ratioProvider: 可选的内容宽高比提供者；返回 nil 表示比例尚未就绪，此时不参与布局。
    ///   - requestLayout: 请求 SwiftUI 重新布局的回调，默认空实现。
    public init(
        state: Bridge.State,
        makeView: @escaping () -> Bridge,
        onIntent: @escaping (Bridge.Intent) -> Void,
        ratioProvider: ((Bridge) -> CGFloat?)? = nil,
        requestLayout: @escaping () -> Void = {}
    ) {
        self.state = state
        self.makeView = makeView
        self.onIntent = onIntent
        self.ratioProvider = ratioProvider
        self.requestLayout = requestLayout
    }

    /// 创建并返回本次装配使用的协调器。
    public func makeCoordinator() -> Coordinator {
        BridgeCoordinator(onIntent: onIntent)
    }

    /// 创建桥视图并装配协调器，同时接通「比例异步就绪 → 请求 SwiftUI 重布局」的兜线。
    ///
    /// - Parameters:
    ///   - context: SwiftUI 提供的装配上下文（可从中取得 coordinator）。
    /// - Returns: 创建好的桥视图。
    public func makeUIView(context: Context) -> Bridge {
        let uiView = makeView()
        context.coordinator.attach(uiView)

        // 「异步比例就绪 → 请求 SwiftUI 重布局」的兜线。
        // 组件侧调用 RatioResolver.resolve 后，会经由 coordinator.onRequestLayout
        // 走到这里：UIKit 侧失效一次 intrinsic size，再把 SwiftUI 侧的布局令牌 +1，
        // 触发一次新布局 → sizeThatFits 用新的比例重新计算高度。
        context.coordinator.onRequestLayout = { [weak uiView, requestLayout] in
            uiView?.invalidateIntrinsicContentSize()
            requestLayout()
        }
        return uiView
    }

    /// 把最新 state 应用到桥视图（值比较早退 / 更新抑制 / 差异映射都由协调器内部完成）。
    ///
    /// - Parameters:
    ///   - uiView: 当前装配的桥视图。
    ///   - context: SwiftUI 提供的装配上下文。
    public func updateUIView(_ uiView: Bridge, context: Context) {
        // 早退 / 抑制 / 差异映射都由 Coordinator 内部完成
        context.coordinator.apply(state)
    }

    /// 桥视图被移除时调用，尽力清理。
    ///
    /// - Note: 不保证被调用；真正确定性的清理在 Coordinator.deinit。
    public static func dismantleUIView(_ uiView: Bridge, coordinator: Coordinator) {
        // ⚠️ 不保证被调用。真正的确定性清理在 Coordinator.deinit。
        coordinator.prepareForDismantle()
    }

    // MARK: - 尺寸自适应通道

    /// 按内容比例计算 SwiftUI 侧应分配的尺寸（宽由 proposal 决定，高 = 宽 / 比例）。
    ///
    /// - Parameters:
    ///   - proposal: SwiftUI 建议的尺寸；宽可能为 nil 或 .infinity，内部会显式翻译。
    ///   - uiView: 当前装配的桥视图。
    ///   - context: SwiftUI 提供的装配上下文。
    /// - Returns: 计算出的尺寸；比例未就绪或宽度非法时返回 nil（此时不参与布局）。
    @available(iOS 16.0, *)
    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: Bridge,
        context: Context
    ) -> CGSize? {
        guard let ratioProvider,
              let ratio = ratioProvider(uiView),
              ratio > 0,
              // ⚠️ proposal 的宽可能是 nil / .infinity，交给 ProposedSizeTranslator 显式翻译，
              //    否则会被当成 0 或无穷参与计算。
              let width = ProposedSizeTranslator.resolveWidth(proposal, fallback: uiView.bounds.width) else {
            return nil
        }

        return CGSize(width: width, height: width / ratio)
    }
}

// MARK: - 声明式外壳（业务唯一依赖的入口）

/// 业务方唯一依赖的入口：把 BridgeView 组件包成 SwiftUI 视图。
///
/// 业务的 SwiftUI 页面只依赖这个类型 + 组件自己的 State / Intent；
/// 内部换了 UIKit 实现、换了通道，业务侧零改动。
public struct BridgeHost<Bridge: BridgeView>: View {

    // 最新数据快照。
    private let state: Bridge.State
    // 桥视图工厂。
    private let makeView: () -> Bridge
    // 意图上报通道的最终去向。
    private let onIntent: (Bridge.Intent) -> Void
    // 可选的内容宽高比提供者。
    private let ratioProvider: ((Bridge) -> CGFloat?)?

    /// 布局回流令牌：比例异步就绪时 +1，触发一次 SwiftUI 重布局，
    /// 让 sizeThatFits 用新比例计算高度（配 makeUIView 里的兜线）。
    @State private var layoutToken = 0

    /// 创建声明式外壳。
    ///
    /// - Parameters:
    ///   - state: 数据快照（可随渲染更新，内部经协调器差异映射到视图）。
    ///   - makeView: 创建桥视图的闭包。
    ///   - onIntent: 意图上报的最终去向。
    ///   - ratioProvider: 可选的内容宽高比提供者；返回 nil 表示比例尚未就绪。
    public init(
        state: Bridge.State,
        makeView: @escaping () -> Bridge,
        onIntent: @escaping (Bridge.Intent) -> Void,
        ratioProvider: ((Bridge) -> CGFloat?)? = nil
    ) {
        self.state = state
        self.makeView = makeView
        self.onIntent = onIntent
        self.ratioProvider = ratioProvider
    }

    /// 桥接视图的内容（转发给 BridgeRepresentable）。
    public var body: some View {
        BridgeRepresentable(
            state: state,
            makeView: makeView,
            onIntent: onIntent,
            ratioProvider: ratioProvider,
            requestLayout: { layoutToken += 1 }
        )
    }
}
