//
//  TextViewComponent.swift
//  SwiftBridgeComponents
//
//  多行输入 —— 表单组件：UITextView 包装，自实现占位符。
//
//  教学点：
//    1. **占位符自实现**：UITextView 没有原生 placeholder → 叠加一个 placeholderLabel，
//       与 textContainerInset / lineFragmentPadding 对齐；text 为空且未在编辑时显示。
//    2. **输入保护**（Demo03 正解）：apply 里只在「未在编辑」时回写 text，
//       防止每次 apply 抢光标 / 打断输入。
//    3. **maxLength**：shouldChangeTextIn 里超限直接拒绝（不掉光标、不多打一轮回调）。
//    4. **无「回车提交」语义**：TextView 里回车就是换行，Intent 只有 .textChanged。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    text            → 输入保护（见上），回写时同步 lastReported
//    placeholder*    → 占位符文案 / 颜色（空态 + 未编辑才显示）
//    border          → roundedRect / plain / 下划线 hairline（复用 TextFieldBorder 三种形态）
//    keyboard        → keyboardType
//    isEditable      → isEditable
//  文字变化触发 textViewDidChange：同步占位符显隐 + lastReported 去重上报 .textChanged。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 多行输入框的展示状态：文本 / 占位符 / 边框 / 键盘 / 可编辑性 / 最大长度。
public struct TextViewState: BridgeState {
    /// 文本框内容。
    public var text: String
    /// 占位符文案；仅 text 为空且未在编辑时显示。
    public var placeholder: String
    /// 占位符配色基调。
    public var placeholderTone: ComponentTone
    /// 边框样式（复用 TextFieldBorder 三种形态）。
    public var border: TextFieldBorder
    /// 键盘类型（映射到 `UIKeyboardType`）。
    public var keyboard: KeyboardKind
    /// 是否可编辑；关闭后只读。
    public var isEditable: Bool
    /// 最大输入长度；nil = 不限。
    public var maxLength: Int?

    /// 构造多行输入框状态。
    /// - Parameters:
    ///   - text: 文本框内容；默认 ""。
    ///   - placeholder: 占位符文案；默认 ""。
    ///   - placeholderTone: 占位符配色基调；默认 .neutral。
    ///   - border: 边框样式；默认 .roundedRect。
    ///   - keyboard: 键盘类型；默认 .standard。
    ///   - isEditable: 是否可编辑；默认 true。
    ///   - maxLength: 最大输入长度；默认 nil（不限）。
    public init(text: String = "",
                placeholder: String = "",
                placeholderTone: ComponentTone = .neutral,
                border: TextFieldBorder = .roundedRect,
                keyboard: KeyboardKind = .standard,
                isEditable: Bool = true,
                maxLength: Int? = nil) {
        self.text = text
        self.placeholder = placeholder
        self.placeholderTone = placeholderTone
        self.border = border
        self.keyboard = keyboard
        self.isEditable = isEditable
        self.maxLength = maxLength
    }
}

/// 多行输入框交互意图：文本内容变化。
public enum TextViewIntent: BridgeIntent {
    /// 文本框内容变化（去重后上报）；回车是换行，没有「提交」语义。
    case textChanged(String)
}

// MARK: - 桥视图

/// 多行输入框桥视图：包装 `UITextView` + 自实现占位符，兼管输入保护与最大长度。
@MainActor
public final class TextViewBridgeView: UIView, BridgeView, UITextViewDelegate {

    /// 桥状态类型：文本 / 占位符 / 边框等。
    public typealias State = TextViewState
    /// 桥意图类型：文本内容变化。
    public typealias Intent = TextViewIntent

    /// 意图上抛回调：文本变化。
    public var onIntent: ((TextViewIntent) -> Void)?

    /// internal（非 private）：留给 @testable 冒烟测试校验占位符 / 文本路径用。
    let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let underline = CALayer()
    /// 上报去重水印：值没变就不上报，防闭环。
    private var lastReported: String?
    private var cached: TextViewState?

    /// 构造组件：搭好多行输入框、占位符标签与边框图层。
    /// - Parameters:
    ///   - frame: 初始 frame。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        // 占位符是叠在 textView 内部的子视图：随滑动区域移动、与文字起点对齐
        textView.chain()
            .font(ComponentTypography.fieldFont())
            .delegate(self)
            .added(to: self)

        placeholderLabel.chain()
            .font(ComponentTypography.fieldFont())
            .numberOfLines(0)
            .isUserInteractionEnabled(false)
            .added(to: textView)

        textView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：宽不固定（宿主铺满），高用组件基线的多行高度。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: ComponentMetrics.textViewHeight())
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        layoutPlaceholder()
        // 下划线 hairline：贴着 textView 底部，宽度跟 textView 走
        let scale = UIScreen.main.scale
        underline.frame = CGRect(x: 0, y: textView.bounds.height - 1 / scale, width: textView.bounds.width, height: 1 / scale)
        underline.backgroundColor = UIColor.separator.cgColor
    }

    // MARK: - BridgeView

    /// 应用最新状态：逐字段差分更新文本 / 占位符 / 边框 / 键盘 / 可编辑性。
    ///
    /// 对应映射见文件头「差异映射字段清单」。
    public func apply(_ state: TextViewState) {
        let prev = cached
        cached = state

        // ⚠️ 输入保护：正在编辑时绝不回写（否则每次 apply 都抢光标、打断输入）
        if !textView.isFirstResponder, textView.text != state.text {
            textView.text = state.text
            lastReported = state.text
            syncPlaceholder()
        }
        if prev?.placeholder != state.placeholder || prev?.placeholderTone != state.placeholderTone {
            let color = ComponentPalette.color(for: state.placeholderTone).withAlphaComponent(0.5)
            placeholderLabel.text = state.placeholder
            placeholderLabel.textColor = color
            syncPlaceholder()
        }
        if prev?.border != state.border {
            applyBorder(state.border)
        }
        if prev?.keyboard != state.keyboard {
            textView.keyboardType = state.keyboard.uiKeyboardType
        }
        if prev?.isEditable != state.isEditable {
            textView.isEditable = state.isEditable
        }
    }

    /// 拆桥：摘除代理、清占位符与边框图层、断意图回调。
    public func teardown() {
        textView.delegate = nil
        placeholderLabel.removeFromSuperview()
        underline.removeFromSuperlayer()
        onIntent = nil
    }

    // MARK: - UITextViewDelegate（最大长度 / 占位符显隐）

    /// 超限输入直接拒绝：比回写截断干净，光标不会跳。
    ///
    /// 仅在设置了 `maxLength` 时参与拦截；未设置则一律放行。
    public func textView(_ textView: UITextView,
                         shouldChangeTextIn range: NSRange,
                         replacementText text: String) -> Bool {
        guard let maxLength = cached?.maxLength else { return true }
        let newText = (textView.text as NSString?)?.replacingCharacters(in: range, with: text) ?? text
        return newText.count <= maxLength
    }

    /// 文字变化：刷占位符显隐 + 去重上报。
    public func textViewDidChange(_ textView: UITextView) {
        syncPlaceholder()
        let current = textView.text ?? ""
        guard lastReported != current else { return }
        lastReported = current
        onIntent?(.textChanged(current))
    }

    /// 开始编辑：占位符隐藏。
    public func textViewDidBeginEditing(_ textView: UITextView) {
        syncPlaceholder()
    }

    /// 结束编辑：空了就显示占位符。
    public func textViewDidEndEditing(_ textView: UITextView) {
        syncPlaceholder()
    }

    // MARK: - 差异映射

    private func applyBorder(_ border: TextFieldBorder) {
        underline.removeFromSuperlayer()
        textView.layer.borderWidth = 0
        textView.layer.cornerRadius = 0
        textView.layer.borderColor = nil
        switch border {
        case .roundedRect:
            textView.layer.borderWidth = 1
            textView.layer.cornerRadius = 10
            textView.layer.borderColor = UIColor.separator.cgColor
            textView.backgroundColor = .systemBackground
        case .plain:
            textView.backgroundColor = .clear
        case .underline:
            textView.backgroundColor = .clear
            textView.layer.addSublayer(underline)   // frame 在 layoutSubviews 里更新
        }
    }

    /// 占位符贴着文字起点：textContainerInset + lineFragmentPadding。
    private func layoutPlaceholder() {
        let inset = textView.textContainerInset
        let padding = textView.textContainer.lineFragmentPadding
        placeholderLabel.frame = CGRect(
            x: inset.left + padding,
            y: inset.top,
            width: textView.bounds.width - inset.left - inset.right - padding * 2,
            height: textView.bounds.height - inset.top - inset.bottom
        )
    }

    /// 占位符显隐：text 为空且未在编辑才显示。
    private func syncPlaceholder() {
        placeholderLabel.isHidden = !(textView.text.isEmpty && !textView.isFirstResponder)
    }
}