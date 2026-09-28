//
//  SliderComponent.swift
//  SwiftBridgeComponents
//
//  滑块 —— 交互组件：UISlider 包装，tone 决定滑动条颜色，可选 step 取整。
//
//  复刻 Demo03 的两个正解：
//    1. 输入保护：拖动中绝不回写 value（sl.isTracking 为 true 时跳过），防抢手势。
//    2. 按 lastReported 去重：valueChanged 里值没变不上报，防闭环。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    value     → 输入保护回写
//    min/max   → 上下界（越界 value 自动被 UISlider 夹住）
//    step      → 上报取整步长；=0 表示连续（默认）
//    tone      → minimumTrackTintColor / thumbTintColor
//    isEnabled → 可用态
//    reportsContinuously → false = 拖拽中不上报，只在松手时报一次（对齐 isContinuous 语义）
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 滑块状态：UISlider 的契约层描述（取值、上下界、步长取整、色调、可用态、连续上报）。
public struct SliderState: BridgeState {
    /// 当前取值。回写受输入保护：拖动中（isTracking）不回写，避免打断手势。
    public var value: Double
    /// 最小值（下界）。
    public var min: Double
    /// 最大值（上界）。
    public var max: Double
    /// = 0 表示连续；> 0 上报时按 step 取整（如 0, 0.1, 0.2 …）。
    public var step: Double
    /// 主题色：决定已滑部分滑动条与滑块的 tint 色。
    public var tone: ComponentTone
    /// 可用态：false 时禁用滑块交互。
    public var isEnabled: Bool
    /// true = 拖动中持续上报；false = 只在松手时上报一次。
    public var reportsContinuously: Bool

    /// 用一个全参调用构建滑块状态；未指定的参数取默认值。
    ///
    /// - Parameters:
    ///   - value: 初始取值；默认 `0`。
    ///   - min: 下界；默认 `0`。
    ///   - max: 上界；默认 `1`。
    ///   - step: 上报取整步长；默认 `0`（连续）。
    ///   - tone: 主题色；默认 `.primary`。
    ///   - isEnabled: 可用态；默认 `true`。
    ///   - reportsContinuously: 是否拖动中持续上报；默认 `true`。
    public init(value: Double,
                min: Double = 0,
                max: Double = 1,
                step: Double = 0,
                tone: ComponentTone = .primary,
                isEnabled: Bool = true,
                reportsContinuously: Bool = true) {
        self.value = value
        self.min = min
        self.max = max
        self.step = step
        self.tone = tone
        self.isEnabled = isEnabled
        self.reportsContinuously = reportsContinuously
    }
}

/// 滑块意图：桥视图上行给调用方的取值变化事件。
public enum SliderIntent: BridgeIntent {
    /// 当前取值变化（已是 step 取整后的结果）。
    case changed(Double)
}

// MARK: - 桥视图

/// 滑块桥视图：UISlider 的 BridgeView 包装，实现 value / min / max / step / tone 等差异映射
/// 与 changed 上行上报，支持连续上报与松手补报。须在主线程（@MainActor）上使用。
@MainActor
public final class SliderBridgeView: UIView, BridgeView {

    /// 本组件对应的状态类型。
    public typealias State = SliderState
    /// 本组件对应的意图类型。
    public typealias Intent = SliderIntent

    /// 上行事件回调：取值变化时把（取整后的）新值回传调用方。
    public var onIntent: ((SliderIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）；`resolvedTheme()` = 本属性 ?? 全局 current。
    public var theme: (any BridgeTheme)?

    /// internal（非 private）：留给 @testable 冒烟测试校验取值与无障碍 label 用。
    let sl = UISlider()
    private var step: Double = 0
    private var reportsContinuously: Bool = true
    private var lastReported: Double?
    private var cached: SliderState?
    /// 最近一次生效的主题缓存：主题变化时强制颜色字段重绘。
    private var cachedTheme: ComponentTheme?

    /// 兼容 frame 初始化：同时挂接 valueChanged（实时上报）与 editingEnded（松手补报）两个事件目标。
    override public init(frame: CGRect) {
        super.init(frame: frame)
        // 值变化实时上报 + 松手补报（第二个 addTarget 走 .also 逃生口）
        sl.chain()
            .target(self, action: #selector(valueChanged), for: .valueChanged)
            .also { $0.addTarget(self, action: #selector(editingEnded), for: [.touchUpInside, .touchUpOutside]) }
            .added(to: self)
        sl.accessibilityLabel = "滑块"

        sl.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    /// 不参与 storyboard 解码，调用即崩溃；请使用 `init(frame:)` 或桥接器创建。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有尺寸：宽度无约束（撑满容器），高度沿用 UISlider 固有值。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: sl.intrinsicContentSize.height)
    }

    // MARK: - BridgeView

    /// 应用新状态：上下界、step、取值、色调、可用态与连续上报按缓存逐项差异映射。
    /// - Note: 拖动中（sl.isTracking）不会回写 value，防止每次 apply 打断用户手势（见文件头正解 1）。
    public func apply(_ state: SliderState) {
        // 主题解析：每桥 override → 全局 current；主题变化强制颜色字段重绘
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if prev?.min != state.min || prev?.max != state.max {
            sl.minimumValue = Float(state.min)
            sl.maximumValue = Float(state.max)
        }
        if prev?.step != state.step {
            step = state.step
        }
        // ⚠️ 输入保护：正在拖动时不回写（否则每次 apply 都打断手势）
        if !sl.isTracking, prev?.value != state.value {
            sl.setValue(Float(state.value), animated: false)
            lastReported = snap(state.value)
        }
        if themeChanged || prev?.tone != state.tone {
            let color = resolvedTheme().color(for: state.tone)
            sl.minimumTrackTintColor = color
            sl.thumbTintColor = color
        }
        if prev?.isEnabled != state.isEnabled {
            sl.isEnabled = state.isEnabled
        }
        if prev?.reportsContinuously != state.reportsContinuously {
            reportsContinuously = state.reportsContinuously
        }
    }

    /// 拆卸：移除全部事件目标并清空回调，避免拆桥后残留回调。
    public func teardown() {
        sl.removeTarget(self, action: nil, for: .allEvents)
        onIntent = nil
    }

    // MARK: - 差异映射

    /// 按 step 取整（连续时原样返回），保留到合理精度。
    private func snap(_ raw: Double) -> Double {
        guard step > 0 else { return raw }
        guard let state = cached else { return raw }
        let n = ((raw - state.min) / step).rounded() * step + state.min
        return min(state.max, max(state.min, n))
    }

    // MARK: - 事件（去重上报）

    @objc private func valueChanged() {
        // 非连续模式：拖动中一律不上报，等松手（editingEnded）补最后一次
        guard reportsContinuously else { return }
        emit()
    }

    /// 拖动结束再补一次，确保松手时的最终值一定上报（含 step 取整结果）。
    @objc private func editingEnded() {
        emit()
    }

    private func emit() {
        let current = snap(Double(sl.value))
        guard lastReported != current else { return }
        lastReported = current
        onIntent?(.changed(current))
    }
}