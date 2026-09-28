//
//  OverlayContainerWindow.swift
//  SwiftBridgeComponents
//
//  弹层宿主窗口 + OverlayManager（设施：弹层容器）。
//
//  OverlayContainerWindow：不 makeKey（不抢 first responder，与键盘友好）、
//  windowLevel 高于 alert。内容（弹层组件）+ 容器视图都被它强持有。
//
//  OverlayManager：窗口注入式 presenter（不走 present(_:)，与 SwiftUI sheet /
//  navigation 零冲突）。单弹层 LIFO 替换：新弹层进来先无动画收掉旧弹层
//  （内容 teardown + 触发其 onDismiss），排队记 future。
//

import UIKit
import SwiftBridgeKit

/// 弹层宿主窗口。
@MainActor
public final class OverlayContainerWindow: UIWindow {

    /// 弹层容器视图（dim + card）。
    public let containerView: OverlayContainerView
    /// 当前承载的弹层桥视图。
    public let contentView: UIView
    /// 本次展示的配置。
    public let presentation: OverlayPresentation
    /// 关闭完成回调是否已触发（幂等：只触发一次）。
    public private(set) var firedOnDismiss = false

    private var onDismiss: (() -> Void)?

    /// 创建弹层宿主窗口。
    ///
    /// - Parameters:
    ///   - contentView: 弹层桥视图（Dialog / ActionSheet / BottomSheet）。
    ///   - presentation: 展示配置。
    ///   - onDismiss: 弹层完全关闭后的业务回调。
    ///   - scene: 目标窗口场景；nil = 从前台场景取，测试无场景时回落主屏 frame。
    init(contentView: UIView, presentation: OverlayPresentation,
         onDismiss: (() -> Void)?, scene: UIWindowScene?) {
        self.containerView = OverlayContainerView(presentation: presentation)
        self.contentView = contentView
        self.presentation = presentation
        self.onDismiss = onDismiss

        let windowScene = scene ?? OverlayContainerWindow.resolveForegroundScene()
        let frame = windowScene?.screen.bounds ?? UIScreen.main.bounds
        if let windowScene {
            super.init(windowScene: windowScene)
        } else {
            super.init(frame: frame)
        }
        self.frame = frame
        self.windowLevel = .alert + 1
        // 不 makeKey：弹层不应该抢走键盘的 first responder 链

        containerView.frame = bounds
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(containerView)
        containerView.host(contentView)

        // 点蒙层 / 拖拽过关卡 → 由管理器走一次正式关闭流程
        containerView.onRequestDismiss = { [weak self] in
            guard self != nil else { return }
            OverlayManager.shared.dismiss()
        }
    }

    /// `NSCoding` 不可用：仅编程式创建。
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 入场动画（由管理器在 isHidden=false 后调用）。
    func animateIn() {
        containerView.animateIn()
    }

    /// 触发一次性关闭回调（幂等）。
    func fireOnDismiss() {
        guard !firedOnDismiss else { return }
        firedOnDismiss = true
        onDismiss?()
        onDismiss = nil
    }

    private static func resolveForegroundScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

// MARK: - OverlayManager

/// 弹层管理器：窗口注入式 presenter，单弹层 LIFO 替换。
@MainActor
public final class OverlayManager {

    /// 全局单例。测试不需要特意重建：present/dismiss 都是幂等操作。
    public static let shared = OverlayManager()

    private init() {}

    private var window: OverlayContainerWindow?

    /// 当前是否有弹层在展示。
    public var isPresenting: Bool { window != nil }

    /// 当前展示的内容视图（供测试断言）。
    public var currentContent: UIView? { window?.contentView }

    /// 当前展示的容器视图（供测试断言层级 / 触发手势）。
    public var container: OverlayContainerView? { window?.containerView }

    /// 展示一个弹层。
    ///
    /// - Parameters:
    ///   - view: 弹层桥视图（Dialog / ActionSheet / BottomSheet）。
    ///   - presentation: 展示配置（默认居中）。
    ///   - onDismiss: 弹层完全关闭后的业务回调。
    ///   - scene: 目标窗口场景；nil = 从前台场景取（测试无场景回落主屏）。
    public func present(view: UIView, presentation: OverlayPresentation = OverlayPresentation(),
                        onDismiss: (() -> Void)? = nil, in scene: UIWindowScene? = nil) {
        // 同一内容已在展示 → 幂等忽略（防止网关重复弹同一实例）
        if let window, window.contentView === view {
            return
        }
        // LIFO 替换：把旧弹层无动画收掉（内容 teardown + 触发其 onDismiss）
        if let old = window {
            finishDismissal(old)
        }

        let window = OverlayContainerWindow(contentView: view, presentation: presentation,
                                            onDismiss: onDismiss, scene: scene)
        window.isHidden = false
        window.animateIn()
        self.window = window
    }

    /// 收起当前弹层。
    ///
    /// - Parameter animated: 是否走出场动画；幂等（没有弹层时静默返回）。
    public func dismiss(animated: Bool = true) {
        guard let window else { return }
        let duration = window.presentation.animationDuration
        if animated, duration > 0 {
            window.containerView.animateOut(duration: duration) { [weak self] in
                self?.finishDismissal(window)
            }
        } else {
            finishDismissal(window)
        }
    }

    // MARK: - 私有

    /// 收容器：内容 teardown + 从屏幕摘除 + 触发 onDismiss。
    private func finishDismissal(_ window: OverlayContainerWindow) {
        (window.contentView as? any BridgeView)?.teardown()
        window.isHidden = true
        window.removeFromSuperview()
        if self.window === window { self.window = nil }
        window.fireOnDismiss()
    }
}