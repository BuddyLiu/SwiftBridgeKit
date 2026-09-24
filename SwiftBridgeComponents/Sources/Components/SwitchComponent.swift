//
//  SwitchComponent.swift
//  SwiftBridgeComponents
//
//  开关 —— 交互组件：UISwitch 包装，tone 决定开合色。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    isOn      → 回写（程序化 set 不会触发 valueChanged，天然防环）
//    tone      → onTintColor
//    isEnabled → 开关可用态
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 开关状态：UISwitch 的契约层描述（开合状态、主题色、可用态）。
public struct SwitchState: BridgeState {
    /// 开合状态：true = 开。
    public var isOn: Bool
    /// 开合色。
    public var tone: ComponentTone
    /// 可用态：false 时禁用开关交互。
    public var isEnabled: Bool

    /// 用一个全参调用构建开关状态；未指定的参数取默认值。
    ///
    /// - Parameters:
    ///   - isOn: 开合状态，必填。
    ///   - tone: 开合色；默认 `.primary`。
    ///   - isEnabled: 可用态；默认 `true`。
    public init(isOn: Bool,
                tone: ComponentTone = .primary,
                isEnabled: Bool = true) {
        self.isOn = isOn
        self.tone = tone
        self.isEnabled = isEnabled
    }
}

/// 开关意图：桥视图上行给调用方的开合变化事件。
public enum SwitchIntent: BridgeIntent {
    /// 开合状态变化。
    case changed(Bool)
}

// MARK: - 桥视图

/// 开关桥视图：UISwitch 的 BridgeView 包装，实现 isOn / tone / isEnabled 差异映射并上行
/// changed 事件。程序化回写不触发事件，与用户手势天然区分。须在主线程（@MainActor）上使用。
@MainActor
public final class SwitchBridgeView: UIView, BridgeView {

    /// 本组件对应的状态类型。
    public typealias State = SwitchState
    /// 本组件对应的意图类型。
    public typealias Intent = SwitchIntent

    /// 上行事件回调：开合变化时把新状态回传调用方。
    public var onIntent: ((SwitchIntent) -> Void)?

    private let sw = UISwitch()
    private var lastReported: Bool?
    private var cached: SwitchState?

    /// 兼容 frame 初始化：事件挂接走链，本体居中由内部 SnapKit 控制，保持 UISwitch 固有尺寸。
    override public init(frame: CGRect) {
        super.init(frame: frame)
        // 事件挂接走链；自身居中由下方 SnapKit 定（translates 自动接管）
        sw.chain()
            .target(self, action: #selector(valueChanged), for: .valueChanged)
            .added(to: self)

        // 让 UISwitch 保持自身固有尺寸，不随容器拉伸；容器顺着居中即可
        sw.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
        }
    }

    /// 不参与 storyboard 解码，调用即崩溃；请使用 `init(frame:)` 或桥接器创建。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有尺寸：完全沿用 UISwitch 自身固有值，不随容器拉伸。
    override public var intrinsicContentSize: CGSize {
        sw.intrinsicContentSize
    }

    // MARK: - BridgeView

    /// 应用新状态：开合、色调、可用态按缓存逐项差异映射。
    /// - Note: isOn 采用程序化赋值，不会触发 valueChanged，故与用户手势天然区分、无闭环。
    public func apply(_ state: SwitchState) {
        let prev = cached
        cached = state

        if prev?.isOn != state.isOn {
            // 程序化赋值不触发 valueChanged → 与用户手势天然区分，无闭环
            sw.isOn = state.isOn
            lastReported = state.isOn
        }
        if prev?.tone != state.tone {
            sw.onTintColor = ComponentPalette.color(for: state.tone)
        }
        if prev?.isEnabled != state.isEnabled {
            sw.isEnabled = state.isEnabled
        }
    }

    /// 拆卸：移除全部事件目标并清空回调，避免拆桥后残留回调。
    public func teardown() {
        sw.removeTarget(self, action: nil, for: .allEvents)
        onIntent = nil
    }

    // MARK: - 事件（去重上报）

    @objc private func valueChanged() {
        let current = sw.isOn
        guard lastReported != current else { return }
        lastReported = current
        onIntent?(.changed(current))
    }
}