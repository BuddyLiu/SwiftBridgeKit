//
//  EmptyStateComponent.swift
//  SwiftBridgeComponents
//
//  空态页 —— 展示为主：图标 + 标题 + 副文案 + 可选主按钮。
//  常见于列表为空、搜索无结果等整页占位。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    title/message → 文案
//    icon          → SF Symbol 名（nil = 默认空盒图标）
//    actionTitle / secondaryActionTitle → 主/次按钮显隐 + 文案（nil = 不显示，俩按钮水平排）
//    tone          → 图标 / 按钮配色
//  点按钮只上报 .actionTapped / .secondaryActionTapped，动作由业务决定（保持「唯一真相」）。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 空态页的展示状态：图标 + 标题 + 副文案 + 可选主 / 次按钮。
public struct EmptyStateState: BridgeState {
    /// 主标题。
    public var title: String
    /// 副文案；nil = 不显示。
    public var message: String?
    /// SF Symbol 名；nil = 默认空盒图标。
    public var icon: String?
    /// nil = 不显示主按钮。
    public var actionTitle: String?
    /// nil = 不显示次级按钮（与主按钮水平并排）。
    public var secondaryActionTitle: String?
    /// 配色主题：图标与按钮配色。
    public var tone: ComponentTone

    /// 构造空态状态。
    /// - Parameters:
    ///   - title: 主标题。
    ///   - message: 副文案；默认 nil（不显示）。
    ///   - icon: SF Symbol 名；默认 nil（用默认空盒图标）。
    ///   - actionTitle: 主按钮文案；默认 nil（不显示主按钮）。
    ///   - secondaryActionTitle: 次级按钮文案；默认 nil（不显示，与主按钮水平并排）。
    ///   - tone: 配色主题；默认 .primary。
    public init(title: String,
                message: String? = nil,
                icon: String? = nil,
                actionTitle: String? = nil,
                secondaryActionTitle: String? = nil,
                tone: ComponentTone = .primary) {
        self.title = title
        self.message = message
        self.icon = icon
        self.actionTitle = actionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.tone = tone
    }
}

/// 空态页交互意图：主 / 次按钮点击。
public enum EmptyStateIntent: BridgeIntent {
    /// 主按钮被点击。
    case actionTapped
    /// 次级按钮被点击。
    case secondaryActionTapped
}

// MARK: - 桥视图

/// 空态页桥视图：图标 + 标题 + 副文案 + 可选主 / 次按钮，垂直排布、展示为主。
@MainActor
public final class EmptyStateBridgeView: UIView, BridgeView {

    /// 桥状态类型：标题 / 文案 / 按钮等展示字段。
    public typealias State = EmptyStateState
    /// 桥意图类型：主 / 次按钮点击。
    public typealias Intent = EmptyStateIntent

    /// 意图上抛回调：主 / 次按钮点击。
    public var onIntent: ((EmptyStateIntent) -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private lazy var actionButton = makeActionButton(#selector(handleAction))
    private lazy var secondaryButton = makeActionButton(#selector(handleSecondaryAction))
    private lazy var buttonStack = makeButtonStack()
    private var cached: EmptyStateState?

    /// 构造组件：搭好图标 / 标题 / 副文案与布局约束；按钮栈按需懒加载。
    /// - Parameters:
    ///   - frame: 初始 frame。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        iconView.chain()
            .contentMode(.scaleAspectFit)
            .added(to: self)

        titleLabel.chain()
            .font(ComponentTypography.emptyTitleFont())
            .textAlignment(.center)
            .added(to: self)

        messageLabel.chain()
            .font(ComponentTypography.emptyMessageFont())
            .textColor(.secondaryLabel)
            .textAlignment(.center)
            .numberOfLines(0)
            .added(to: self)

        // 垂直堆叠：图标 → 标题 → 副文案 → 按钮，全部水平居中
        iconView.snp.makeConstraints { make in
            make.top.equalTo(self).offset(24)
            make.centerX.equalTo(self)
            make.size.equalTo(ComponentMetrics.emptyIconSize())
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(12)
            make.centerX.equalTo(self)
            make.leading.greaterThanOrEqualTo(self).offset(24)
            make.trailing.lessThanOrEqualTo(self).offset(-24)
        }

        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.centerX.equalTo(self)
            make.leading.greaterThanOrEqualTo(self).offset(32)
            make.trailing.lessThanOrEqualTo(self).offset(-32)
        }
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：宽不固定；高 = 基础空态高，有按钮时追加按钮高与间距。
    override public var intrinsicContentSize: CGSize {
        // 高度：图标 48 + 标题/副文案 + 上下留白；有按钮再 + 按钮高 + 间距
        let base = ComponentMetrics.emptyStateHeight()
        let hasButtons = cached?.actionTitle != nil || cached?.secondaryActionTitle != nil
        let extra = hasButtons ? ComponentMetrics.buttonHeight(for: .small) + 16 : 0
        return CGSize(width: UIView.noIntrinsicMetric, height: base + extra)
    }

    // MARK: - BridgeView

    /// 应用最新状态：逐字段差分更新文案 / 图标 / 配色 / 按钮显隐。
    /// - Parameters:
    ///   - state: 最新的空态状态。
    public func apply(_ state: EmptyStateState) {
        let prev = cached
        cached = state

        if prev?.title != state.title {
            titleLabel.text = state.title
        }
        if prev?.message != state.message {
            messageLabel.text = state.message
            messageLabel.isHidden = state.message == nil
        }
        if prev?.icon != state.icon {
            iconView.image = UIImage(systemName: state.icon ?? Self.defaultIcon)
        }
        if prev?.tone != state.tone {
            let color = ComponentPalette.color(for: state.tone)
            iconView.tintColor = color
            actionButton.backgroundColor = color
            actionButton.setTitleColor(.white, for: .normal)
            secondaryButton.backgroundColor = color
            secondaryButton.setTitleColor(.white, for: .normal)
        }
        if prev?.actionTitle != state.actionTitle || prev?.secondaryActionTitle != state.secondaryActionTitle {
            let hasAny = state.actionTitle != nil || state.secondaryActionTitle != nil
            if hasAny {
                actionButton.setTitle(state.actionTitle, for: .normal)
                secondaryButton.setTitle(state.secondaryActionTitle, for: .normal)
                actionButton.isHidden = state.actionTitle == nil
                secondaryButton.isHidden = state.secondaryActionTitle == nil
                // remakeConstraints 幂等：反复显隐/改文案不会累积重复约束
            if buttonStack.superview == nil {
                addSubview(buttonStack)
            }
            buttonStack.snp.remakeConstraints { make in
                make.top.equalTo(messageLabel.snp.bottom).offset(16)
                make.centerX.equalTo(self)
                make.height.equalTo(ComponentMetrics.buttonHeight(for: .small))
            }
            actionButton.snp.remakeConstraints { make in
                make.width.equalTo(ComponentMetrics.emptyActionWidth())
            }
            secondaryButton.snp.remakeConstraints { make in
                make.width.equalTo(ComponentMetrics.emptyActionWidth())
            }
            } else {
                buttonStack.removeFromSuperview()
            }
            invalidateIntrinsicContentSize()
        }
    }

    /// 拆桥：移除按钮 target，清掉意图回调。
    public func teardown() {
        actionButton.removeTarget(self, action: nil, for: .allEvents)
        secondaryButton.removeTarget(self, action: nil, for: .allEvents)
        onIntent = nil
    }

    // MARK: - 差异映射

    private static let defaultIcon = "tray"

    private func makeActionButton(_ action: Selector) -> UIButton {
        UIButton.chain(type: .custom)
            .font(ComponentTypography.buttonFont(for: .small))
            .cornerRadius(ComponentMetrics.buttonCornerRadius(for: .small))
            .target(self, action: action, for: .touchUpInside)
            .autolayout()
            .build()
    }

    private func makeButtonStack() -> UIStackView {
        UIStackView.chain(arrangedSubviews: [actionButton, secondaryButton])
            .axis(.horizontal)
            .alignment(.fill)
            .spacing(12)
            .autolayout()
            .build()
    }

    @objc private func handleAction() {
        onIntent?(.actionTapped)
    }

    @objc private func handleSecondaryAction() {
        onIntent?(.secondaryActionTapped)
    }
}