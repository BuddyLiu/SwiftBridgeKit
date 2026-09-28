//
//  StepperComponent.swift
//  SwiftBridgeComponents
//
//  步进器 —— 交互组件：UIStepper 包装，加减改值。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    value       → stepper.value（程序化赋值不触发 valueChanged → 天然防环，同 Switch/Slider）
//    min/max/step/wraps/autorepeat → 直写 UIStepper 对应属性
//    tone        → stepper.tintColor
//    isEnabled   → isEnabled
//  用户加减触发 valueChanged：lastReported 去重后上报 .changed(value)，
//  业务把值回写进 state，链路自收敛（值没变就不再动）。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 步进器的展示状态：数值范围 + 步长 + 回绕/连发 + 配色与可用性。
public struct StepperState: BridgeState {
    /// 当前值。
    public var value: Double
    /// 最小值。
    public var min: Double
    /// 最大值。
    public var max: Double
    /// 步长。
    public var step: Double
    /// 到界是否回绕（max 后再加回到 min）。
    public var wraps: Bool
    /// 长按是否连发。
    public var autorepeat: Bool
    /// 配色主题：步进器高亮色。
    public var tone: ComponentTone
    /// 是否可交互。
    public var isEnabled: Bool

    /// 构造步进器状态。
    /// - Parameters:
    ///   - value: 当前值；默认 0。
    ///   - min: 最小值；默认 0。
    ///   - max: 最大值；默认 10。
    ///   - step: 步长；默认 1。
    ///   - wraps: 到界回绕；默认 false。
    ///   - autorepeat: 长按连发；默认 true。
    ///   - tone: 配色主题；默认 .primary。
    ///   - isEnabled: 是否可交互；默认 true。
    public init(value: Double = 0,
                min: Double = 0,
                max: Double = 10,
                step: Double = 1,
                wraps: Bool = false,
                autorepeat: Bool = true,
                tone: ComponentTone = .primary,
                isEnabled: Bool = true) {
        self.value = value
        self.min = min
        self.max = max
        self.step = step
        self.wraps = wraps
        self.autorepeat = autorepeat
        self.tone = tone
        self.isEnabled = isEnabled
    }
}

/// 步进器交互意图：数值变化。
public enum StepperIntent: BridgeIntent {
    /// 用户加减后上报新值；是否落进 state 由业务决定并回写。
    case changed(Double)
}

// MARK: - 桥视图

/// 步进器桥视图：包装 `UIStepper`，加减只上报意图，值回写由业务驱动。
@MainActor
public final class StepperBridgeView: UIView, BridgeView {

    /// 桥状态类型：数值范围 + 步长 + 配色等。
    public typealias State = StepperState
    /// 桥意图类型：数值变化。
    public typealias Intent = StepperIntent

    /// 意图上抛回调：数值变化。
    public var onIntent: ((StepperIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）；`resolvedTheme()` = 本属性 ?? 全局 current。
    public var theme: (any BridgeTheme)?

    /// internal（非 private）：留给 @testable 冒烟测试校验 apply 写值用。
    let stepper = UIStepper()
    /// 上报去重水印：值没变就不上报，防闭环。
    private var lastReported: Double?
    private var cached: StepperState?
    /// 最近一次生效的主题缓存：主题变化时强制颜色字段重绘。
    private var cachedTheme: ComponentTheme?

    /// 构造组件：搭好 UIStepper 与居中约束。
    /// - Parameters:
    ///   - frame: 初始 frame。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        stepper.chain()
            .accessibilityLabel("步进器")
            .target(self, action: #selector(valueChanged), for: .valueChanged)
            .added(to: self)

        stepper.snp.makeConstraints { make in
            make.centerX.equalTo(self)
            make.centerY.equalTo(self)
        }
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：跟随 UIStepper 本身。
    override public var intrinsicContentSize: CGSize {
        stepper.intrinsicContentSize
    }

    // MARK: - BridgeView

    /// 应用最新状态：逐字段差分更新数值 / 范围 / 步长 / 回绕 / 连发 / 配色。
    /// - Parameters:
    ///   - state: 最新的步进器状态。
    public func apply(_ state: StepperState) {
        // 主题解析：每桥 override → 全局 current；主题变化强制颜色字段重绘
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        // 程序化赋值不触发 valueChanged：天然防环；仍同步 lastReported 兜底
        if stepper.value != state.value {
            stepper.value = state.value
            lastReported = state.value
        }
        if stepper.minimumValue != state.min { stepper.minimumValue = state.min }
        if stepper.maximumValue != state.max { stepper.maximumValue = state.max }
        if stepper.stepValue != state.step { stepper.stepValue = state.step }
        if stepper.wraps != state.wraps { stepper.wraps = state.wraps }
        if stepper.autorepeat != state.autorepeat { stepper.autorepeat = state.autorepeat }
        if themeChanged || prev?.tone != state.tone {
            stepper.tintColor = resolvedTheme().color(for: state.tone)
        }
        if stepper.isEnabled != state.isEnabled { stepper.isEnabled = state.isEnabled }
    }

    /// 拆桥：摘除 target 事件并清掉意图回调。
    public func teardown() {
        stepper.removeTarget(self, action: nil, for: .allEvents)
        onIntent = nil
    }

    // MARK: - 事件（去重上报）

    @objc private func valueChanged() {
        let current = stepper.value
        guard lastReported != current else { return }
        lastReported = current
        onIntent?(.changed(current))
    }
}