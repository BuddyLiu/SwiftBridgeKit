//
//  ChipComponent.swift
//  SwiftBridgeComponents
//
//  标签 —— 交互组件：选中的标签，圆角 pill 底 + 边框；选中态由业务回写。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    title        → 文案 + invalidateIntrinsic（宽度自适应）
//    tone         → 选中底色 / 文字色 / 边框色
//    isSelected   → 选中与未选中两套配色 + 加粗切换
//    isEnabled    → 手势开关 + alpha
//    icon         → 前置图标（SF Symbol，16pt）
//    showsCheckmark → 选中时左前缀 checkmark（覆盖 icon，白勾反白）
//  点击只上报 .tapped，选中与否由业务决定并回写（保持「唯一真相」）。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 标签（chip）的展示状态：文案 / 配色 / 选中 / 可用 / 图标，选中态由业务回写。
public struct ChipState: BridgeState {
    /// 标签文案，居中显示。
    public var title: String
    /// 配色主题：选中底色 / 文字色 / 边框色。
    public var tone: ComponentTone
    /// 选中态。由业务回写驱动，视图不自己翻转。
    public var isSelected: Bool
    /// 是否可交互；不可用时关手势并降到半透明（alpha 0.5）。
    public var isEnabled: Bool
    /// 前置图标；选中且 showsCheckmark 时被 checkmark 覆盖。
    public var icon: String?
    /// 选中时显示 checkmark 前缀。
    public var showsCheckmark: Bool

    /// 构造标签状态。
    /// - Parameters:
    ///   - title: 标签文案。
    ///   - tone: 配色主题；默认 .primary。
    ///   - isSelected: 是否选中；默认 false。
    ///   - isEnabled: 是否可交互；默认 true。
    ///   - icon: 前置图标（SF Symbol 名）；默认 nil。
    ///   - showsCheckmark: 选中时是否显示 checkmark 前缀；默认 false。
    public init(title: String,
                tone: ComponentTone = .primary,
                isSelected: Bool = false,
                isEnabled: Bool = true,
                icon: String? = nil,
                showsCheckmark: Bool = false) {
        self.title = title
        self.tone = tone
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.icon = icon
        self.showsCheckmark = showsCheckmark
    }
}

/// 标签交互意图：点击。
public enum ChipIntent: BridgeIntent {
    /// 标签被点击；是否选中由业务决定并回写。
    case tapped
}

// MARK: - 桥视图

/// 标签（pill）桥视图：圆角 pill 底 + 边框，点击只上报意图，选中态由业务回写驱动。
@MainActor
public final class ChipBridgeView: UIView, BridgeView {

    /// 桥状态类型：文案 / 配色 / 选中 / 可用 / 图标。
    public typealias State = ChipState
    /// 桥意图类型：点击。
    public typealias Intent = ChipIntent

    /// 意图上抛回调：点击标签。
    public var onIntent: ((ChipIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）。nil = 回落全局 `ComponentTheme.current`。
    public var theme: (any BridgeTheme)?
    /// 上次解析生效的主题缓存：变化时强制重绘颜色（themeChanged）。
    private var cachedTheme: ComponentTheme?

    private let iconView = UIImageView()
    private let label = UILabel()
    private let stack = UIStackView()
    private var cached: ChipState?

    /// 构造组件：搭好水平栈（图标 + 文案）、点击手势与布局约束。
    /// - Parameters:
    ///   - frame: 初始 frame。
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.chain().clipsToBounds(true)

        // 无障碍：整个 chip 是一个按钮语义的读屏元素（label/value 由 apply 更新）
        isAccessibilityElement = true
        accessibilityTraits = [.button]

        // 图标：16pt 前置，默认隐藏；arranged 子视图统一走栈管理
        iconView.chain()
            .contentMode(.scaleAspectFit)
            .isHidden(true)
            .autolayout()
            .build()

        label.chain()
            .font(ComponentTypography.chipFont())
            .textAlignment(.center)
            .autolayout()
            .build()

        // 水平栈：图标 + 文案，整体居中；栈与 chip 等高、alignment 居中
        stack.chain()
            .axis(.horizontal)
            .alignment(.center)
            .spacing(ComponentMetrics.chipIconSpacing())
            .arrangedSubviews([iconView, label])
            .added(to: self)
            .build()

        stack.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(self).offset(ComponentMetrics.chipPaddingX())
            make.trailing.equalTo(self).offset(-ComponentMetrics.chipPaddingX())
        }

        iconView.snp.makeConstraints { make in
            make.size.equalTo(ComponentMetrics.chipIconSize())
        }

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：宽度随文案 + 图标自适应，高度固定 chipHeight（32）。
    override public var intrinsicContentSize: CGSize {
        let font = label.font ?? ComponentTypography.chipFont()
        let textWidth = (cached?.title as NSString?)?.size(withAttributes: [.font: font]).width ?? 0
        // 内容宽度 + 图标（含间距）+ 左右各 padding；高度固定 32
        let iconWidth: CGFloat = iconView.isHidden ? 0 : ComponentMetrics.chipIconSize() + ComponentMetrics.chipIconSpacing()
        return CGSize(width: ceil(textWidth) + iconWidth + ComponentMetrics.chipPaddingX() * 2,
                      height: ComponentMetrics.chipHeight())
    }

    /// 布局：把圆角设成高度的一半，维持 pill 形态。
    override public func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2     // pill
    }

    // MARK: - BridgeView

    /// 应用最新状态：逐字段差分更新文案 / 图标 / 配色 / 可用性。
    /// - Parameters:
    ///   - state: 最新的标签状态。
    public func apply(_ state: ChipState) {
        // 主题解析：每桥覆盖优先，否则回落全局 current；themeChanged 时强制重绘颜色
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if prev?.title != state.title {
            label.text = state.title
            // 单元素读屏：label = 文案
            accessibilityLabel = state.title
            invalidateIntrinsicContentSize()
        }
        if prev?.icon != state.icon || prev?.showsCheckmark != state.showsCheckmark {
            syncIcon(state, theme: theme)
            invalidateIntrinsicContentSize()
        }
        if themeChanged || prev?.tone != state.tone || prev?.isSelected != state.isSelected {
            applySelectionStyle(state, theme: theme)
        }
        if prev?.isSelected != state.isSelected {
            // 读屏 value：选中态补 "已选"，未选中回落默认
            accessibilityValue = state.isSelected ? "已选" : nil
        }
        if prev?.isEnabled != state.isEnabled {
            isUserInteractionEnabled = state.isEnabled
            alpha = state.isEnabled ? 1 : 0.5
        }
    }

    /// 拆桥：清掉意图回调。
    public func teardown() {
        onIntent = nil
    }

    // MARK: - 差异映射

    private func applySelectionStyle(_ state: ChipState, theme: ComponentTheme) {
        let color = theme.color(for: state.tone)
        if state.isSelected {
            backgroundColor = color
            label.textColor = .white
            label.font = ComponentTypography.chipFont()   // 选中保持同字号
            layer.borderWidth = 0
            layer.borderColor = nil
        } else {
            backgroundColor = .systemGray6
            label.textColor = .label
            layer.borderWidth = 1
            layer.borderColor = UIColor.separator.cgColor
        }
        // 选中态切换会影响图标配色/是否换成 checkmark，跟随刷新
        syncIcon(state, theme: theme)
    }

    /// 图标优先级：选中且 showsCheckmark → checkmark（反白）；有 icon → tone 色（选中反白）；否则隐藏。
    private func syncIcon(_ state: ChipState, theme: ComponentTheme) {
        if state.showsCheckmark && state.isSelected {
            iconView.image = UIImage(systemName: "checkmark")
            iconView.tintColor = .white
            iconView.isHidden = false
        } else if let name = state.icon {
            iconView.image = UIImage(systemName: name)
            iconView.tintColor = state.isSelected ? .white : theme.color(for: state.tone)
            iconView.isHidden = false
        } else {
            iconView.image = nil
            iconView.isHidden = true
        }
    }

    // MARK: - 事件

    @objc private func handleTap() {
        onIntent?(.tapped)
    }
}