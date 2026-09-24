//
//  BadgeComponent.swift
//  SwiftBridgeComponents
//
//  徽章 —— 纯展示组件：文案/数字、色调、形态（pill / 圆角）、可选右上角圆点。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    text       → label 文案（可按 maxValue 截断成 "99+"）+ invalidateIntrinsic（宽度自适应）
//    maxValue   → 溢出截断上限（纯函数 BadgeFormat 决定显示文本）
//    tone       → 浅底 / 文字色 / 角点色
//    shape      → 圆角（在 layoutSubviews 按实际高度重算）
//    showsDot   → 角点显隐
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 徽章的状态：文案 + 色调 + 形态 + 可选角点，数字可做溢出截断。
public struct BadgeState: BridgeState {
    /// 徽章文案，可为文本或整数；整数可被 maxValue 截断为 "99+"。
    public var text: String
    /// 溢出截断上限：text 是整数且超过它 → 显示 "\(maxValue)+"；nil = 不截断。
    public var maxValue: Int?
    /// 徽章色调：决定浅底、文字与角点颜色。
    public var tone: ComponentTone
    /// 徽章形态：pill 胶囊或 round 小圆角。
    public var shape: BadgeShape
    /// 右上角 8×8 圆点。
    public var showsDot: Bool

    /// 用给定内容创建徽章状态。
    /// - Parameters:
    ///   - text: 徽章文案。
    ///   - maxValue: 溢出截断上限，nil 不截断。
    ///   - tone: 徽章色调，默认 primary。
    ///   - shape: 徽章形态，默认 round。
    ///   - showsDot: 是否显示右上角圆点，默认关闭。
    public init(text: String,
                maxValue: Int? = nil,
                tone: ComponentTone = .primary,
                shape: BadgeShape = .round,
                showsDot: Bool = false) {
        self.text = text
        self.maxValue = maxValue
        self.tone = tone
        self.shape = shape
        self.showsDot = showsDot
    }
}

// MARK: - 数字溢出（纯计算，可单测）

/// 徽章文案的溢出截断：text 是整数字符串且 > 上限 → "99+"；其余原样。
enum BadgeFormat {
    static func displayText(_ text: String, maxValue: Int?) -> String {
        guard let maxValue, let number = Int(text) else { return text }
        return number > maxValue ? "\(maxValue)+" : text
    }
}

// MARK: - 桥视图

/// 徽章的桥视图：按 State 差异映射渲染，宽度随内容自适应。
@MainActor
public final class BadgeBridgeView: UIView, BridgeView {

    /// 组件状态类型：徽章状态。
    public typealias State = BadgeState
    /// 意图类型：纯展示组件无事件，用空意图 NoIntent。
    public typealias Intent = NoIntent

    /// 意图回调：本组件纯展示，保留通道便于扩展。
    public var onIntent: ((NoIntent) -> Void)?

    private let label = UILabel()
    private let dot = UIView()
    private var cached: BadgeState?

    /// 初始化桥视图：装配文案 label 与右上角圆点，并建立约束。
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.chain().clipsToBounds(true)

        label.chain()
            .font(ComponentTypography.badgeFont())
            .textAlignment(.center)
            .added(to: self)

        // 右上角圆点：8×8，锚到右上角 (-2, -2)
        dot.chain()
            .cornerRadius(4)
            .isHidden(true)
            .added(to: self)

        label.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(self).offset(16)
            make.trailing.equalTo(self).offset(-16)
        }

        // 右上角圆点：8×8，锚到右上角 (-2, -2)
        dot.snp.makeConstraints { make in
            make.size.equalTo(8)
            make.top.equalTo(self).offset(-2)
            make.trailing.equalTo(self).offset(2)
        }
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 内容宽度（按当前显示文本测量）加左右各 16pt 内边距；高度固定。
    override public var intrinsicContentSize: CGSize {
        // label.font 是 IUO，显式落到非可选再入字典，避免隐式解包提示
        let font = label.font ?? ComponentTypography.badgeFont()
        let textWidth = (displayText() as NSString?)?.size(withAttributes: [.font: font]).width ?? 0
        // 内容宽度 + 左右各 16pt padding；高度固定 22
        return CGSize(width: ceil(textWidth) + 32, height: ComponentMetrics.badgeHeight())
    }

    /// 当前应显示的文本（含溢出截断）。
    private func displayText() -> String {
        guard let state = cached else { return "" }
        return BadgeFormat.displayText(state.text, maxValue: state.maxValue)
    }

    /// 布局时按实际高度重算圆角：pill 取高度一半，round 取小圆角。
    override public func layoutSubviews() {
        super.layoutSubviews()
        // pill = 高度一半；round = 小圆角（不超过高度一半）
        layer.cornerRadius = ComponentMetrics.badgeCornerRadius(
            shape: cached?.shape ?? .round,
            height: bounds.height
        )
    }

    // MARK: - BridgeView

    /// 把 State 快照差异映射到视图上。
    public func apply(_ state: BadgeState) {
        let prev = cached
        cached = state

        if prev?.text != state.text || prev?.maxValue != state.maxValue {
            label.text = displayText()
            invalidateIntrinsicContentSize()
        }
        if prev?.tone != state.tone {
            let color = ComponentPalette.color(for: state.tone)
            backgroundColor = ComponentPalette.softBackground(for: state.tone)
            label.textColor = color
            dot.backgroundColor = color
        }
        if prev?.shape != state.shape {
            setNeedsLayout()
        }
        if prev?.showsDot != state.showsDot {
            dot.isHidden = !state.showsDot
        }
    }

    /// 拆除桥视图：断开意图通道（纯展示组件无观察者）。
    public func teardown() {
        // 展示型组件无观察者，只要断开通道
        onIntent = nil
    }
}