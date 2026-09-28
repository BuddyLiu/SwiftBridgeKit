//
//  TextFieldComponent.swift
//  SwiftBridgeComponents
//
//  输入框 —— 表单组件：占位符（可定制颜色）、清除按钮、键盘类型、首字母图标、边框样式。
//
//  复刻 Demo03 的两个正解：
//    1. 输入保护：apply 里只在「未在编辑」时回写 text，防止抢光标 / 打断输入。
//    2. 按 lastReported 去重：editingChanged 里值没变就不上报，防闭环。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    text          → 输入保护（见上）
//    placeholder*  → attributedPlaceholder 前景色
//    showsClearButton → clearButtonMode
//    keyboard      → uiKeyboardType
//    leadingIcon   → leftView（SF Symbol）
//    border        → roundedRect / none / 下划线 hairline CALayer
//    isSecure      → isSecureTextEntry（密码）
//    maxLength     → delegate 在 shouldChangeCharactersIn 里拒绝超限输入（不掉光标）
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 输入框组件的 State：文本、占位符、清除按钮、键盘类型、首图标与边框样式。
///
/// 各字段均有默认值，业务端可只传关心的字段；`apply(_:)` 按字段逐一对比，
/// 未变化的字段不会触发更新。
public struct TextFieldState: BridgeState {
    /// 输入框当前文本。
    public var text: String
    /// 占位符文案。
    public var placeholder: String
    /// 占位符颜色（纯值）。视图在 apply 里翻译成半透明的 UIColor。
    public var placeholderTone: ComponentTone
    /// 是否在编辑时显示清除按钮。
    public var showsClearButton: Bool
    /// 键盘类型（映射到 `UIKeyboardType`）。
    public var keyboard: KeyboardKind
    /// 首字母图标（SF Symbol 名）；nil = 不显示。
    public var leadingIcon: String?
    /// 边框样式：圆角 / 无边框 / 下划线。
    public var border: TextFieldBorder
    /// 密码模式（圆点遮盖）。
    public var isSecure: Bool
    /// 最大输入长度；nil = 不限。
    public var maxLength: Int?

    /// 构造输入框状态。
    ///
    /// - Parameters:
    ///   - text: 输入框当前文本。
    ///   - placeholder: 占位符文案（默认 `""`）。
    ///   - placeholderTone: 占位符颜色基调（默认 `.neutral`）。
    ///   - showsClearButton: 是否在编辑时显示清除按钮（默认 `true`）。
    ///   - keyboard: 键盘类型（默认 `.standard`）。
    ///   - leadingIcon: 首字母图标 SF Symbol 名；nil = 不显示（默认 `nil`）。
    ///   - border: 边框样式（默认 `.roundedRect`）。
    ///   - isSecure: 是否密码模式（默认 `false`）。
    ///   - maxLength: 最大输入长度；nil = 不限（默认 `nil`）。
    public init(text: String,
                placeholder: String = "",
                placeholderTone: ComponentTone = .neutral,
                showsClearButton: Bool = true,
                keyboard: KeyboardKind = .standard,
                leadingIcon: String? = nil,
                border: TextFieldBorder = .roundedRect,
                isSecure: Bool = false,
                maxLength: Int? = nil) {
        self.text = text
        self.placeholder = placeholder
        self.placeholderTone = placeholderTone
        self.showsClearButton = showsClearButton
        self.keyboard = keyboard
        self.leadingIcon = leadingIcon
        self.border = border
        self.isSecure = isSecure
        self.maxLength = maxLength
    }
}

/// 输入框交互意图：文本变化上报与回车提交。
public enum TextFieldIntent: BridgeIntent {
    /// 文本变化（经 `lastReported` 去重后上报）。
    case textChanged(String)
    /// 键盘「完成」键回车。
    case submitted
}

// MARK: - 桥视图

/// 输入框桥视图：包装 `UITextField` 与可选下划线边框，把契约层状态映射到 UIKit 控件，
/// 并把用户输入/提交转成 `TextFieldIntent` 上报。
@MainActor
public final class TextFieldBridgeView: UIView, BridgeView, UITextFieldDelegate {

    /// 关联的契约状态类型。
    public typealias State = TextFieldState
    /// 关联的契约意图类型。
    public typealias Intent = TextFieldIntent

    /// 意图回调：用户输入变化 / 回车提交在此上报给宿主。
    public var onIntent: ((TextFieldIntent) -> Void)?

    /// internal（非 private）：留给 @testable 冒烟测试校验占位符回写 / 无障碍 label。
    let field = UITextField()
    private let underline = CALayer()
    private var lastReported: String?
    private var cached: TextFieldState?
    /// 上次生效主题：换肤重放 apply 时强制重建占位符前景色。
    private var cachedTheme: ComponentTheme?

    /// 以 frame 创建桥视图，并完成输入框约束布局、事件源与代理挂接。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        // 输入框本体：形态/字体/清除/回车/代理 + 两个事件；尺寸由下方 SnapKit 定
        field.chain()
            .borderStyle(.roundedRect)
            .font(ComponentTypography.fieldFont())
            .clearButtonMode(.whileEditing)
            .returnKeyType(.done)
            .delegate(self)
            .target(self, action: #selector(editingChanged), for: .editingChanged)
            .target(self, action: #selector(editingSubmitted), for: .primaryActionTriggered)
            .added(to: self)
        // 无障碍默认：跟随系统字体缩放（大字体用户受益）
        field.adjustsFontForContentSizeCategory = true

        field.snp.makeConstraints { make in
            make.top.equalTo(self).offset(6)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(ComponentMetrics.fieldHeight() - 12)
        }
    }

    /// `NSCoding` 初始化器不可用：组件仅支持编程式创建（`init(frame:)`）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固定内容尺寸：宽度交给 `noIntrinsicMetric` 自适应，高度取组件输入框规格。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: ComponentMetrics.fieldHeight())
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        // 下划线 hairline：贴着 field 底部，宽度跟 field 走
        let scale = UIScreen.main.scale
        underline.frame = CGRect(x: 0, y: field.bounds.height - 1 / scale, width: field.bounds.width, height: 1 / scale)
        underline.backgroundColor = UIColor.separator.cgColor
    }

    // MARK: - BridgeView

    /// 按状态差异更新输入框：正在编辑时绝不回写文本（输入保护），其余字段仅在差异时刷新。
    ///
    /// 对应映射见文件头「差异映射字段清单」。
    public func apply(_ state: TextFieldState) {
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        let placeholderChanged = prev?.placeholder != state.placeholder
        let placeholderToneChanged = prev?.placeholderTone != state.placeholderTone

        // ⚠️ 输入保护：正在编辑时绝不回写（否则每次 apply 都抢光标、打断输入）
        if !field.isFirstResponder, field.text != state.text {
            field.text = state.text
            lastReported = state.text
        }
        // 无障碍：占位文案非空 → 读屏 label 用占位文案（placeholder 变才写，别每帧写）
        if placeholderChanged {
            field.accessibilityLabel = state.placeholder.isEmpty ? nil : state.placeholder
        }
        // 主题化：占位符前景色走 resolvedTheme()；换肤重放 apply 时用 themeChanged 强刷
        if themeChanged || placeholderChanged || placeholderToneChanged {
            let color = resolvedTheme().color(for: state.placeholderTone).withAlphaComponent(0.5)
            field.attributedPlaceholder = NSAttributedString(
                string: state.placeholder,
                attributes: [.foregroundColor: color, .font: field.font ?? ComponentTypography.fieldFont()]
            )
        }
        if prev?.showsClearButton != state.showsClearButton {
            field.clearButtonMode = state.showsClearButton ? .whileEditing : .never
        }
        if prev?.keyboard != state.keyboard {
            field.keyboardType = state.keyboard.uiKeyboardType
        }
        if prev?.leadingIcon != state.leadingIcon {
            applyLeadingIcon(state.leadingIcon)
        }
        if prev?.border != state.border {
            applyBorder(state.border)
        }
        if prev?.isSecure != state.isSecure {
            field.isSecureTextEntry = state.isSecure
        }
    }

    /// 拆除桥视图：摘除输入框目标事件与代理，并断开意图回调，避免悬垂引用。
    public func teardown() {
        field.removeTarget(self, action: nil, for: .allEvents)
        field.delegate = nil
        onIntent = nil
    }

    // MARK: - UITextFieldDelegate（最大长度）

    /// 超限输入直接拒绝：比回写截断干净，光标不会跳、也不多打一轮 editingChanged。
    ///
    /// 仅在设置了 `maxLength` 时参与拦截；未设置则一律放行。
    ///
    /// - Parameters:
    ///   - textField: 触发校验的输入框（组件内置的 `field`）。
    ///   - range: 即将被替换的字符区间。
    ///   - string: 本次输入 / 粘贴的替换文本。
    /// - Returns: 允许本次输入返回 `true`；超过最大长度时返回 `false` 直接拒绝。
    public func textField(_ textField: UITextField,
                          shouldChangeCharactersIn range: NSRange,
                          replacementString string: String) -> Bool {
        guard let maxLength = cached?.maxLength else { return true }
        let newText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? string
        return newText.count <= maxLength
    }

    // MARK: - 差异映射

    private func applyLeadingIcon(_ name: String?) {
        if let name {
            let imageView = UIImageView(image: UIImage(systemName: name))
            imageView.tintColor = .secondaryLabel
            imageView.contentMode = .center
            imageView.frame = CGRect(x: 0, y: 0, width: 32, height: 20)
            field.leftView = imageView
            field.leftViewMode = .always
        } else {
            field.leftView = nil
            field.leftViewMode = .never
        }
    }

    private func applyBorder(_ border: TextFieldBorder) {
        underline.removeFromSuperlayer()
        switch border {
        case .roundedRect:
            field.borderStyle = .roundedRect
        case .plain:
            field.borderStyle = .none
        case .underline:
            field.borderStyle = .none
            field.layer.addSublayer(underline)   // frame 在 layoutSubviews 里更新
        }
    }

    // MARK: - 事件（去重上报）

    @objc private func editingChanged() {
        let current = field.text ?? ""
        guard lastReported != current else { return }
        lastReported = current
        onIntent?(.textChanged(current))
    }

    @objc private func editingSubmitted() {
        onIntent?(.submitted)
    }
}