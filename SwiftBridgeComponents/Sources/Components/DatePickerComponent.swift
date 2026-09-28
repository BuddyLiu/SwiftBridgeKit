//
//  DatePickerComponent.swift
//  SwiftBridgeComponents
//
//  日期选择器 —— 交互组件：UIDatePicker 包装（非倒计时用 compact，倒计时自动切 wheels）。
//
//  教学点：
//    1. **compact 样式在 SwiftUI 行的正确高度**：intrinsic 高度取 picker 的真实高度、
//       宽度 noIntrinsicMetric（交给宿主铺满），避免自动撑出过高的行。
//    2. **countDown 与 date 语义分离**：倒计时模式改的是 countDownDuration 而不是 date，
//       Intent 单独出 .countDownChanged，避免拿到「无意义的日期」。
//    3. **countDown 与 compact 互斥**（UIKit 事实）：UIDatePickerMode.countDownTimer
//       在 .compact 样式下直接抛 NSInternalInconsistencyException → 切到倒计时前必须先换
//       .wheels 样式；样式与模式必须按序切换（先让当前组合合法，再换下一个）。
//    4. **countDownDuration 契约为 60 的倍数**（UIDatePicker 的事实）：init 里纯函数钳制
//       到 60 的倍数且非负，越界值进不到 UIKit。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    date            → 非 countDown 模式写 picker.date（程序化赋值不触发 valueChanged → 天然防环）
//    countDownDuration → countDown 模式写 picker.countDownDuration
//    kind            → 模式 + 样式按序切换（countDown 用 wheels，其余 compact）
//    tone            → picker.tintColor
//    isEnabled       → isEnabled
//  valueChanged 里按当前模式分支上报：日期 / 倒计时时长（各配 lastReported 去重）。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 日期选择器的展示状态：日期 + 模式 + 倒计时时长 + 配色与可用性。
public struct DatePickerState: BridgeState {
    /// 选择出的日期；countDown 模式下无意义（只用 countDownDuration）。
    public var date: Date
    /// 选择模式（date / time / dateAndTime / countDown）。
    public var kind: DatePickerKind
    /// 倒计时时长（秒）。契约为 60 的倍数，init 里就近取整并钳非负。
    public var countDownDuration: TimeInterval
    /// 配色主题：选择器高亮色。
    public var tone: ComponentTone
    /// 是否可交互。
    public var isEnabled: Bool

    /// 构造日期选择器状态。
    /// - Parameters:
    ///   - date: 选择出的日期；默认当前时刻。
    ///   - kind: 选择模式；默认 .date。
    ///   - countDownDuration: 倒计时时长（秒）；默认 0。init 里就近取整到 60 的倍数并钳非负。
    ///   - tone: 配色主题；默认 .primary。
    ///   - isEnabled: 是否可交互；默认 true。
    public init(date: Date = Date(),
                kind: DatePickerKind = .date,
                countDownDuration: TimeInterval = 0,
                tone: ComponentTone = .primary,
                isEnabled: Bool = true) {
        self.date = date
        self.kind = kind
        // UIDatePicker.countDownDuration 必须是 60 的倍数：就近取整 + 钳非负（纯函数，可单测）
        self.countDownDuration = max(0, (countDownDuration / 60).rounded()) * 60
        self.tone = tone
        self.isEnabled = isEnabled
    }
}

/// 日期选择器交互意图：日期变化 / 倒计时变化（countDown 模式单独出，避免 Date 语义混淆）。
public enum DatePickerIntent: BridgeIntent {
    /// 非倒计时模式下选择了新日期。
    case changed(Date)
    /// 倒计时模式下改动了时长（秒）。
    case countDownChanged(TimeInterval)
}

// MARK: - 桥视图

/// 日期选择器桥视图：包装 `UIDatePicker`，按模式分支上报日期 / 倒计时。
@MainActor
public final class DatePickerBridgeView: UIView, BridgeView {

    /// 桥状态类型：日期 + 模式等。
    public typealias State = DatePickerState
    /// 桥意图类型：日期变化 / 倒计时变化。
    public typealias Intent = DatePickerIntent

    /// 意图上抛回调：日期 / 倒计时变化。
    public var onIntent: ((DatePickerIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）；`resolvedTheme()` = 本属性 ?? 全局 current。
    public var theme: (any BridgeTheme)?

    /// internal（非 private）：留给 @testable 冒烟测试校验 apply 写值用。
    let picker = UIDatePicker()
    /// 上报去重水印：日期一个、倒计时一个，值没变就不上报。
    private var lastReportedDate: Date?
    private var lastReportedDuration: TimeInterval?
    private var cached: DatePickerState?
    /// 最近一次生效的主题缓存：主题变化时强制颜色字段重绘。
    private var cachedTheme: ComponentTheme?

    /// 构造组件：搭好 compact 选择器、值变化事件与边缘约束。
    /// - Parameters:
    ///   - frame: 初始 frame。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        picker.chain()
            .datePickerMode(.date)
            .preferredDatePickerStyle(.compact)
            .accessibilityLabel("日期选择")
            .target(self, action: #selector(valueChanged), for: .valueChanged)
            .added(to: self)

        picker.snp.makeConstraints { make in
            make.top.bottom.equalTo(self)
            make.leading.trailing.equalTo(self)
        }
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：宽不固定（宿主铺满），高取 compact picker 的真实行高，避免行被撑高。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: picker.intrinsicContentSize.height)
    }

    // MARK: - BridgeView

    /// 应用最新状态：按模式分支写 date / countDownDuration，其余字段差分更新。
    /// - Parameters:
    ///   - state: 最新的日期选择器状态。
    public func apply(_ state: DatePickerState) {
        // 主题解析：每桥 override → 全局 current；主题变化强制颜色字段重绘
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if prev?.kind != state.kind {
            applyKind(state.kind)
        }

        // 模式切换会自动收敛到对应读取源：countDown 走时长、其余走日期
        if state.kind == .countDown {
            if prev?.countDownDuration != state.countDownDuration {
                picker.countDownDuration = state.countDownDuration
                lastReportedDuration = state.countDownDuration
            }
        } else if prev?.date != state.date {
            picker.date = state.date
            lastReportedDate = state.date
        }

        if themeChanged || prev?.tone != state.tone {
            picker.tintColor = resolvedTheme().color(for: state.tone)
        }
        if picker.isEnabled != state.isEnabled { picker.isEnabled = state.isEnabled }
    }

    /// 拆桥：摘除 target 事件并清掉意图回调。
    public func teardown() {
        picker.removeTarget(self, action: nil, for: .allEvents)
        onIntent = nil
    }

    // MARK: - 差异映射

    /// 模式切换：样式与模式按序切换，避免「countDown 配 compact」这种非法组合。
    /// countDown 模式用 .wheels（.compact 不支持并直接抛异常），其余模式用 .compact。
    private func applyKind(_ kind: DatePickerKind) {
        let wasCountDown = picker.datePickerMode == .countDownTimer
        let isCountDown = kind == .countDown
        if isCountDown {
            // 先进合法组合（date + wheels），再切倒计时
            picker.preferredDatePickerStyle = .wheels
            picker.datePickerMode = .countDownTimer
        } else if wasCountDown {
            // 先退出倒计时（countDownTimer 配 wheels 合法），再换 compact
            picker.datePickerMode = .date
            picker.preferredDatePickerStyle = .compact
            picker.datePickerMode = kind.uiMode
        } else {
            picker.datePickerMode = kind.uiMode
            picker.preferredDatePickerStyle = .compact
        }
        // 样式/模式会影响高度（countDown → wheels 变高）：让 SwiftUI 重算行高
        invalidateIntrinsicContentSize()
    }

    // MARK: - 事件（按模式分支去重上报）

    @objc private func valueChanged() {
        // 模式以 UIKit 实况为准（valueChanged 可能先于 apply 触发）
        if picker.datePickerMode == .countDownTimer {
            let current = picker.countDownDuration
            guard lastReportedDuration != current else { return }
            lastReportedDuration = current
            onIntent?(.countDownChanged(current))
        } else {
            let current = picker.date
            guard lastReportedDate != current else { return }
            lastReportedDate = current
            onIntent?(.changed(current))
        }
    }
}