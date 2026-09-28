//
//  ProgressBarComponent.swift
//  SwiftBridgeComponents
//
//  进度条 —— 展示组件：determinate 百分比 + indeterminate 转圈加载态，tone 换色。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    progress        → setProgress（首帧不动画，之后带动画）
//    tone            → progressTintColor / trackTintColor / 转圈色
//    isIndeterminate → 进度条与转圈二者互斥显隐
//
//  只展示不交互，Intent 走 NoIntent。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 进度条状态：determinate 百分比 + 是否转圈加载，色调统一。
public struct ProgressBarState: BridgeState {
    /// 进度，钳制到 [0, 1]。
    public var progress: Float
    /// 进度条与转圈的色调。
    public var tone: ComponentTone
    /// 是否为不确定态：隐藏进度条、转圈表示加载中。
    public var isIndeterminate: Bool

    /// 创建进度条状态。
    /// - Parameters:
    ///   - progress: 进度百分比，默认 0，钳制到 [0, 1]。
    ///   - tone: 色调，默认 `.primary`。
    ///   - isIndeterminate: 是否为转圈加载态，默认 `false`。
    public init(progress: Float = 0,
                tone: ComponentTone = .primary,
                isIndeterminate: Bool = false) {
        // 契约层保证不变量：视图侧无需再防越界
        self.progress = min(max(progress, 0), 1)
        self.tone = tone
        self.isIndeterminate = isIndeterminate
    }
}

// MARK: - 桥视图

@MainActor
/// 进度条桥视图：展示型组件，determinate 百分比 / indeterminate 转圈互斥，tone 换色。
public final class ProgressBarBridgeView: UIView, BridgeView {

    /// 桥状态：进度与形态。
    public typealias State = ProgressBarState
    /// 桥事件类型固定为 `NoIntent`：展示型组件不上报事件。
    public typealias Intent = NoIntent

    /// 事件上报通道：展示型组件无事件，保留以适配 BridgeView 协议。
    public var onIntent: ((NoIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）；`resolvedTheme()` = 本属性 ?? 全局 current。
    public var theme: (any BridgeTheme)?

    private let progressView = UIProgressView(progressViewStyle: .default)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var cached: ProgressBarState?
    /// 最近一次生效的主题缓存：主题变化时强制颜色字段重绘。
    private var cachedTheme: ComponentTheme?

    /// 创建进度条桥视图：容器裁 pill 圆角，内部放 UIProgressView 与转圈。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        let height = ComponentMetrics.progressBarHeight()
        // 容器裁圆角：UIProgressView 的方角填充在圆角容器里被裁出 pill 形
        self.chain()
            .clipsToBounds(true)
            .cornerRadius(height / 2)
            // 无障碍：容器单元素（进度内容收敛为一个 VoiceOver 元素），值随 apply 维护
            .isAccessibilityElement(true)
            .accessibilityLabel("进度")
            .accessibilityTraits([.updatesFrequently])

        progressView.chain()
            .added(to: self)

        spinner.chain()
            .hidesWhenStopped(true)
            .added(to: self)

        progressView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        spinner.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    /// 不支持：仅满足 NSCoding 编译要求。
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 高度用组件度量，宽度交由外部布局。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: ComponentMetrics.progressBarHeight())
    }

    // MARK: - BridgeView

    /// 应用新状态：进度首帧直接落位、此后带动画；tone 换色；indeterminate 互斥显隐。
    public func apply(_ state: ProgressBarState) {
        // 主题解析：每桥 override → 全局 current；主题变化强制颜色字段重绘
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if prev?.progress != state.progress {
            // 首帧直接落位：避免从 0 滑过去；后续变化带动画
            progressView.setProgress(state.progress, animated: prev != nil)
            if !state.isIndeterminate {
                accessibilityValue = "\(Int(state.progress * 100))%"
            }
        }
        if themeChanged || prev?.tone != state.tone {
            applyTone(state.tone)
        }
        if prev?.isIndeterminate != state.isIndeterminate {
            applyIndeterminate(state.isIndeterminate)
            // 无障碍：value 随形态更新（转圈 = 加载中，否则百分比）
            accessibilityValue = state.isIndeterminate ? "加载中" : "\(Int(state.progress * 100))%"
        }
    }

    /// 拆桥：停转圈并清事件通道。
    public func teardown() {
        spinner.stopAnimating()
        onIntent = nil
    }

    // MARK: - 差异映射

    private func applyTone(_ tone: ComponentTone) {
        let theme = resolvedTheme()
        let color = theme.color(for: tone)
        progressView.progressTintColor = color
        progressView.trackTintColor = theme.softBackground(for: tone)
        spinner.color = color
    }

    private func applyIndeterminate(_ indeterminate: Bool) {
        progressView.isHidden = indeterminate
        if indeterminate {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }
}