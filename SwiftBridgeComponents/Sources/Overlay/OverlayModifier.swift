//
//  OverlayModifier.swift
//  SwiftBridgeComponents
//
//  弹层的 SwiftUI 门面（设施：弹层容器）。
//
//  本文件是弹层设施里**唯一 import SwiftUI** 的文件：
//  · View.overlayPresent(isPresented:state:makeView:options:onIntent:onDismiss:)
//    业务侧唯一入口，把 UIKit 弹层组件包成声明式门面；
//  · OverlayGateway —— @MainActor 小对象，收口「装配 coordinator + 弹/收容器」，
//    跨演员调用全部包在 `Task { @MainActor in }` 里（strict concurrency 零告警关键）；
//  · onValueChange —— iOS 17 起 onChange(of:perform:) 弃用，双分支壳保证零告警。
//
//  lifecycle 三钩：
//    · .onAppear         首帧若已 isPresented（深链直达）也要弹；
//    · .onValueChange(isPresented) 弹/收切换（onChange 不触发首帧，故上一条托底）；
//    · .onValueChange(state)       展示中改 state（如 BottomSheet 连选）差异下行；
//    · .onDisappear      宿主页面消失时收掉容器，防漏弹层残留。
//

import SwiftUI
import SwiftBridgeKit

// MARK: - 业务唯一入口

public extension View {

    /// 以窗口注入方式弹出 UIKit 弹层组件（Dialog / ActionSheet / BottomSheet）。
    ///
    /// - Parameters:
    ///   - isPresented: 显隐绑定；置 true 弹出，置 false 收起。
    ///   - state: 弹层最新数据快照（随渲染差异下行到已弹出的组件）。
    ///   - makeView: 创建弹层桥视图的闭包。
    ///   - options: 展示配置（位置/蒙层/点蒙层关/拖拽关/动画时长，默认居中）。
    ///   - onIntent: 弹层意图上报（Dialog.tapped / ActionSheet.tapped / BottomSheet.changed 等）。
    ///   - onDismiss: 弹层完全关闭后的业务回调（清状态等幂等操作）。
    func overlayPresent<V: BridgeView & OverlayDismissChannel>(
        isPresented: Binding<Bool>,
        state: V.State,
        makeView: @escaping () -> V,
        options: OverlayPresentation = OverlayPresentation(),
        onIntent: ((V.Intent) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(OverlayModifier(
            isPresented: isPresented,
            state: state,
            makeView: makeView,
            options: options,
            onIntent: onIntent,
            onDismiss: onDismiss
        ))
    }
}

// MARK: - 弹层网关（跨演员收口）

/// 弹层网关：@MainActor 小对象，装配 coordinator + 管理「弹/收容器」。
///
/// 每次 `show()` 用同一个 view + coordinator（组件可复用）；
/// 隐藏后再次展示会重新 attach（teardown 已断开上报通道，attach 会重新接通）。
@MainActor
private final class OverlayGateway<V: BridgeView & OverlayDismissChannel> {

    private let makeView: () -> V
    private let options: OverlayPresentation
    private let onIntent: ((V.Intent) -> Void)?
    private let onDismiss: (() -> Void)?

    private var state: V.State
    private var coordinator: BridgeCoordinator<V>?
    private var view: V?

    init(state: V.State, makeView: @escaping () -> V, options: OverlayPresentation,
         onIntent: ((V.Intent) -> Void)?, onDismiss: (() -> Void)?) {
        self.state = state
        self.makeView = makeView
        self.options = options
        self.onIntent = onIntent
        self.onDismiss = onDismiss
    }

    /// 存最新状态；已弹出时差异下行（coordinator 内部做了值比较早退）。
    func sync(_ newState: V.State) {
        state = newState
        coordinator?.apply(state)
    }

    /// 弹出。已装配的 view 直接（再）present；否则先装配再弹。
    func show() {
        if let coordinator, let view {
            // 复用同一实例：teardown 断开的通道重新接上
            coordinator.attach(view)
            view.onRequestDismiss = { [weak self] in
                self?.hide()
            }
            present(view, coordinator: coordinator)
            return
        }

        let view = makeView()
        let coordinator = BridgeCoordinator<V>(onIntent: { [weak self] intent in
            self?.onIntent?(intent)
        })
        coordinator.attach(view)
        view.onRequestDismiss = { [weak self] in
            self?.hide()
        }
        present(view, coordinator: coordinator)
        self.view = view
        self.coordinator = coordinator
    }

    /// 收起（幂等）：只关自己正在展示的容器，不误伤 LIFO 换进来的新弹层。
    func hide() {
        guard let current = OverlayManager.shared.currentContent, current === view else { return }
        OverlayManager.shared.dismiss()
    }

    private func present(_ view: V, coordinator: BridgeCoordinator<V>) {
        OverlayManager.shared.present(view: view, presentation: options, onDismiss: { [weak self] in
            self?.onDismiss?()
        })
        coordinator.apply(state)
    }
}

// MARK: - 修饰器

/// 弹层修饰器：生命周期三钩 + 网关持有。
private struct OverlayModifier<V: BridgeView & OverlayDismissChannel>: ViewModifier {

    @Binding var isPresented: Bool
    let state: V.State
    let makeView: () -> V
    let options: OverlayPresentation
    let onIntent: ((V.Intent) -> Void)?
    let onDismiss: (() -> Void)?

    @State private var gateway: OverlayGateway<V>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                Task { @MainActor in
                    makeGatewayIfNeeded()
                    gateway?.sync(state)
                    if isPresented { gateway?.show() }   // onChange 不触发首帧，这里托底深链直达
                }
            }
            .onValueChange(of: isPresented) { newValue in
                Task { @MainActor in
                    makeGatewayIfNeeded()
                    if newValue {
                        gateway?.sync(state)
                        gateway?.show()
                    } else {
                        gateway?.hide()
                    }
                }
            }
            .onValueChange(of: state) { newValue in
                Task { @MainActor in
                    makeGatewayIfNeeded()
                    gateway?.sync(newValue)   // 展示中改 state（如连选）差异下行
                }
            }
            .onDisappear {
                Task { @MainActor in
                    gateway?.hide()
                }
            }
    }

    @MainActor
    private func makeGatewayIfNeeded() {
        guard gateway == nil else { return }
        gateway = OverlayGateway(state: state, makeView: makeView, options: options,
                                 onIntent: onIntent, onDismiss: onDismiss)
    }
}

// MARK: - onChange 双分支壳（iOS 17 弃用零告警）

extension View {

    /// onChange 双分支：iOS 17+ 用新签名（含旧/新值），旧系统回落旧 API。
    /// 旧 API 被本函数（标记 deprecated 100000）调用，编译器不再告警。
    @ViewBuilder
    func onValueChange<Value: Equatable>(of value: Value,
                                         _ action: @escaping (Value) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            legacyOnValueChange(of: value, action)
        }
    }

    @available(iOS, deprecated: 100000)
    private func legacyOnValueChange<Value: Equatable>(of value: Value,
                                                       _ action: @escaping (Value) -> Void) -> some View {
        self.onChange(of: value) { newValue in
            action(newValue)
        }
    }
}