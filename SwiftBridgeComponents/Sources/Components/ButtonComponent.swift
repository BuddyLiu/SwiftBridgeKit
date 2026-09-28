//
//  ButtonComponent.swift
//  SwiftBridgeComponents
//
//  按钮 —— 交互组件：样式枚举 × 尺寸枚举，支持 icon、禁用、加载态。
//
//  差异映射字段清单（apply 里逐字段比较，不动的就不写）：
//    style / size → 重建配色 + 高度/字体/圆角（size 变化需 invalidateIntrinsic）
//    title / icon / loadingTitle → 回填（loading 态显示 loadingTitle 或空）
//    iconPosition  → 图标相对文字的位置（leading / trailing）
//    isEnabled     → button.isEnabled + alpha
//    isLoading     → 菊花覆盖 + 自动禁用（详见 updateLoading）
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 按钮的状态：样式 × 尺寸的组合，支持图标、禁用与加载态。
public struct ButtonState: BridgeState {
    /// 按钮文案。
    public var title: String
    /// 按钮样式：primary / secondary / outline / ghost / danger。
    public var style: ButtonStyle
    /// 按钮尺寸：决定高度、字体与圆角。
    public var size: ButtonSize
    /// SF Symbol 名（纯值，可 Equatable）——刻意不用 UIImage。
    public var icon: String?
    /// 图标相对文字的位置。
    public var iconPosition: ButtonIconPosition
    /// 是否可交互；禁用时按钮置灰并降低透明度。
    public var isEnabled: Bool
    /// 是否处于加载态：显示菊花、隐藏图标并自动禁用。
    public var isLoading: Bool
    /// 加载期间的文案；nil = 只转菊花不显示文字。
    public var loadingTitle: String?

    /// 用给定内容创建按钮状态。
    /// - Parameters:
    ///   - title: 按钮文案。
    ///   - style: 按钮样式，默认 primary。
    ///   - size: 按钮尺寸，默认 regular。
    ///   - icon: SF Symbol 名，nil 不显示图标。
    ///   - iconPosition: 图标相对文字的位置，默认 leading。
    ///   - isEnabled: 是否可交互，默认 true。
    ///   - isLoading: 是否加载态，默认 false。
    ///   - loadingTitle: 加载期间的文案，nil 只显示菊花。
    public init(title: String,
                style: ButtonStyle = .primary,
                size: ButtonSize = .regular,
                icon: String? = nil,
                iconPosition: ButtonIconPosition = .leading,
                isEnabled: Bool = true,
                isLoading: Bool = false,
                loadingTitle: String? = nil) {
        self.title = title
        self.style = style
        self.size = size
        self.icon = icon
        self.iconPosition = iconPosition
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.loadingTitle = loadingTitle
    }
}

/// 按钮的用户意图：点击。
public enum ButtonIntent: BridgeIntent {
    /// 用户点击了按钮。
    case tap
}

// MARK: - 桥视图

/// 按钮的桥视图：按 State 差异映射渲染，点击事件经 onIntent 上抛。
@MainActor
public final class ButtonBridgeView: UIView, BridgeView {

    /// 组件状态类型：按钮状态。
    public typealias State = ButtonState
    /// 意图类型：按钮的点击意图。
    public typealias Intent = ButtonIntent

    /// 意图回调：把按钮点击事件上抛给宿主。
    public var onIntent: ((ButtonIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）；`resolvedTheme()` = 本属性 ?? 全局 current。
    public var theme: (any BridgeTheme)?

    private let button = UIButton(type: .custom)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var cached: ButtonState?
    /// 最近一次生效的主题缓存：主题变化时强制颜色字段重绘。
    private var cachedTheme: ComponentTheme?

    /// 初始化桥视图：装配 UIButton 与加载菊花、建立约束，并挂上点击事件。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        // 按钮本体：字体 + 点击事件；尺寸/高度由下方 SnapKit 撑起
        button.chain()
            .font(ComponentTypography.buttonFont(for: .regular))
            .target(self, action: #selector(handleTap), for: .touchUpInside)
            .added(to: self)

        spinner.chain()
            .hidesWhenStopped(true)
            .added(to: self)

        button.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(ComponentMetrics.buttonHeight(for: .regular))
        }

        spinner.snp.makeConstraints { make in
            make.centerX.centerY.equalTo(button)
        }
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 高度按缓存 State 的 size 决定，宽度交给外部约束指定。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: ComponentMetrics.buttonHeight(for: cached?.size ?? .regular))
    }

    // MARK: - BridgeView

    /// 把 State 快照差异映射到视图上。
    public func apply(_ state: ButtonState) {
        // 主题解析：每桥 override → 全局 current；主题变化强制颜色字段重绘
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if themeChanged || prev?.style != state.style || prev?.size != state.size {
            applyStyleAndSize()
        }
        if prev?.title != state.title || prev?.icon != state.icon || prev?.loadingTitle != state.loadingTitle {
            syncTitleAndIcon()
        }
        if prev?.iconPosition != state.iconPosition {
            applyIconPosition(state.iconPosition)
        }
        if prev?.isEnabled != state.isEnabled {
            applyEnabled(state.isEnabled)
        }
        if prev?.isLoading != state.isLoading {
            updateLoading()
        }
    }

    /// 拆除桥视图：移除按钮事件、停止加载菊花并断开意图通道。
    public func teardown() {
        button.removeTarget(self, action: nil, for: .allEvents)
        spinner.stopAnimating()
        onIntent = nil
    }

    // MARK: - 差异映射

    private func applyStyleAndSize() {
        guard let state = cached else { return }
        let theme = resolvedTheme()
        let colors = theme.buttonColors(for: state.style)

        button.setTitleColor(colors.foreground, for: .normal)
        button.backgroundColor = colors.background
        button.tintColor = colors.foreground
        button.titleLabel?.font = ComponentTypography.buttonFont(for: state.size)
        button.layer.cornerRadius = ComponentMetrics.buttonCornerRadius(for: state.size)

        switch state.style {
        case .outline:
            button.layer.borderWidth = 1.5
            button.layer.borderColor = theme.buttonOutlineColor().cgColor
        default:
            button.layer.borderWidth = 0
            button.layer.borderColor = nil
        }

        invalidateIntrinsicContentSize()
    }

    private func applyEnabled(_ enabled: Bool) {
        button.isEnabled = enabled
        button.alpha = enabled ? 1 : resolvedTheme().buttonDisabledAlpha()
    }

    /// loading 状态机：菊花覆盖 + 隐藏图标（按需保留 loadingTitle）+ 强制禁用；结束按缓存回填。
    private func updateLoading() {
        guard let state = cached else { return }

        if state.isLoading {
            button.isEnabled = false
            button.isUserInteractionEnabled = false
            button.setTitle(state.loadingTitle, for: .normal)
            button.setImage(nil, for: .normal)
            spinner.color = resolvedTheme().buttonColors(for: state.style).foreground
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
            button.isUserInteractionEnabled = true
            applyEnabled(state.isEnabled)
            syncTitleAndIcon()
        }
    }

    private func syncTitleAndIcon() {
        guard let state = cached else { return }
        if state.isLoading {
            button.setTitle(state.loadingTitle, for: .normal)
            button.setImage(nil, for: .normal)
            return
        }
        button.setTitle(state.title, for: .normal)
        button.setImage(state.icon.flatMap { UIImage(systemName: $0) }, for: .normal)
    }

    /// 图标相对文字的位置：trailing 用 forceRightToLeft 换序。
    /// （不碰 imageEdgeInsets/titleEdgeInsets：iOS 15 起已被 UIButtonConfiguration 弃用，
    ///  text↔image 间距沿用系统默认值即可，保持零告警。）
    private func applyIconPosition(_ position: ButtonIconPosition) {
        switch position {
        case .leading:
            button.semanticContentAttribute = .forceLeftToRight
        case .trailing:
            button.semanticContentAttribute = .forceRightToLeft
        }
    }

    // MARK: - 事件

    @objc private func handleTap() {
        onIntent?(.tap)
    }
}