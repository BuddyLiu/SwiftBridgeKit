//
//  SegmentedComponent.swift
//  SwiftBridgeComponents
//
//  分段选择 —— 交互组件：UISegmentedControl 包装，选中段用 tone 高亮。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    items          → 重建分段（内容变化才 removeAllSegments + 逐个插入）
//    selectedIndex  → selectedSegmentIndex（程序化赋值不触发事件，无闭环）
//    tone           → 选中段底色 + 选中/普通标题色
//    isEnabled      → 可用态
//    isMomentary    → 瞬时模式：松手即清选中，同一段可重复上报（按钮型 tabs）
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 分段选择状态：UISegmentedControl 的契约层描述（段标题、选中索引、色调、可用态、瞬时模式）。
public struct SegmentedState: BridgeState {
    /// 段标题列表；内容变化时桥视图会重建全部分段。
    public var items: [String]
    /// 当前选中段的索引；越界值会被夹到有效范围，空列表时为 noSegment。
    public var selectedIndex: Int
    /// 主题色：决定选中段底色与选中 / 普通标题色。
    public var tone: ComponentTone
    /// 可用态：false 时禁用分段交互。
    public var isEnabled: Bool
    /// 瞬时模式（momentary）：点击上报后不保持选中态，适合「按钮型 tabs」。
    public var isMomentary: Bool

    /// 用一个全参调用构建分段状态；未指定的参数取默认值。
    ///
    /// - Parameters:
    ///   - items: 段标题列表，必填。
    ///   - selectedIndex: 初始选中索引；默认 `0`。
    ///   - tone: 主题色；默认 `.primary`。
    ///   - isEnabled: 可用态；默认 `true`。
    ///   - isMomentary: 瞬时模式；默认 `false`（点击后保持选中态）。
    public init(items: [String],
                selectedIndex: Int = 0,
                tone: ComponentTone = .primary,
                isEnabled: Bool = true,
                isMomentary: Bool = false) {
        self.items = items
        self.selectedIndex = selectedIndex
        self.tone = tone
        self.isEnabled = isEnabled
        self.isMomentary = isMomentary
    }
}

/// 分段选中意图：桥视图上行给调用方的选中事件。
public enum SegmentedIntent: BridgeIntent {
    /// 选中段的索引变化。
    case changed(Int)
}

// MARK: - 桥视图

/// 分段选择桥视图：UISegmentedControl 的 BridgeView 包装，负责 items → 分段重建、
/// selectedIndex → 选中态的差异映射，并上行 changed 事件。须在主线程（@MainActor）上使用。
@MainActor
public final class SegmentedBridgeView: UIView, BridgeView {

    /// 本组件对应的状态类型。
    public typealias State = SegmentedState
    /// 本组件对应的意图类型。
    public typealias Intent = SegmentedIntent

    /// 上行事件回调：选中段变化时把新索引回传调用方。
    public var onIntent: ((SegmentedIntent) -> Void)?

    private let seg = UISegmentedControl()
    private var lastReported: Int?
    private var cached: SegmentedState?

    /// 兼容 frame 初始化：事件挂接走链，布局由内部 SnapKit 控制。
    override public init(frame: CGRect) {
        super.init(frame: frame)
        // 事件挂接走链；尺寸/位置由下方 SnapKit 定
        seg.chain()
            .target(self, action: #selector(valueChanged), for: .valueChanged)
            .added(to: self)

        seg.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }

    /// 不参与 storyboard 解码，调用即崩溃；请使用 `init(frame:)` 或桥接器创建。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有尺寸：高度沿用 UISegmentedControl 固有值，宽度无约束（撑满行宽）。
    override public var intrinsicContentSize: CGSize {
        // 高度交给 UISegmentedControl 固有值，宽度 noIntrinsic（撑满行宽）
        CGSize(width: UIView.noIntrinsicMetric, height: seg.intrinsicContentSize.height)
    }

    // MARK: - BridgeView

    /// 应用新状态：段列表变化时重建全部分段并连带重设选中，其余字段按缓存逐项差异映射。
    public func apply(_ state: SegmentedState) {
        let prev = cached
        cached = state

        if prev?.items != state.items {
            seg.removeAllSegments()
            for (i, item) in state.items.enumerated() {
                seg.insertSegment(withTitle: item, at: i, animated: false)
            }
            // 分段重建后 selectedIndex 语义可能变，连带重设
            syncSelection(state)
        } else if prev?.selectedIndex != state.selectedIndex {
            syncSelection(state)
        }
        if prev?.tone != state.tone {
            applyTone(state.tone)
        }
        if prev?.isEnabled != state.isEnabled {
            seg.isEnabled = state.isEnabled
        }
        if prev?.isMomentary != state.isMomentary {
            seg.isMomentary = state.isMomentary
        }
    }

    /// 拆卸：移除全部事件目标并清空回调，避免拆桥后残留回调。
    public func teardown() {
        seg.removeTarget(self, action: nil, for: .allEvents)
        onIntent = nil
    }

    // MARK: - 差异映射

    private func syncSelection(_ state: SegmentedState) {
        let target = state.items.isEmpty ? UISegmentedControl.noSegment
                    : min(max(state.selectedIndex, 0), state.items.count - 1)
        if seg.selectedSegmentIndex != target {
            seg.selectedSegmentIndex = target
            lastReported = target == UISegmentedControl.noSegment ? nil : target
        }
    }

    private func applyTone(_ tone: ComponentTone) {
        let color = ComponentPalette.color(for: tone)
        seg.selectedSegmentTintColor = color
        // 选中段统一白字（深色底保证对比度）；普通段默认色
        seg.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        seg.setTitleTextAttributes([.foregroundColor: UIColor.label], for: .normal)
    }

    // MARK: - 事件（去重上报）

    @objc private func valueChanged() {
        let current = seg.selectedSegmentIndex
        guard lastReported != current else { return }
        lastReported = current
        onIntent?(.changed(current))
        // 瞬时模式：系统会自动清掉选中，重置水印让同一段也能重复上报
        if seg.isMomentary {
            lastReported = nil
        }
    }
}