//
//  Chain+UITextView.swift
//  SwiftChainKit
//
//  多行文本输入：内容/字体/编辑态/选择态/检测类型 + 键盘 trait（与 UITextField 同源
//  UITextInputTraits）。滚动相关属性来自 Chain+UIScrollView 基座（UITextView 是
//  UIScrollView 子类），不在此重复。

import UIKit

/// `UITextView` 链式设置：多行文本内容、字体、编辑/选择态、检测类型与键盘 trait。
///
/// 滚动相关属性来自 `Chain<UIScrollView>` 基座，不在此重复。
public extension Chain where Base: UITextView {

    /// 设置文本内容。
    ///
    /// 等价直接给 `base.text` 赋值。
    /// - Parameter text: 显示文本。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func text(_ text: String?) -> Chain<Base> {
        base.text = text
        return self
    }

    /// 设置富文本内容。
    ///
    /// 等价直接给 `base.attributedText` 赋值，优先级高于 `text`。
    /// - Parameter text: 富文本内容。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func attributedText(_ text: NSAttributedString?) -> Chain<Base> {
        base.attributedText = text
        return self
    }

    /// 设置字体。
    ///
    /// 等价直接给 `base.font` 赋值。
    /// - Parameter font: 字体。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func font(_ font: UIFont?) -> Chain<Base> {
        base.font = font
        return self
    }

    /// 设置文字颜色。
    ///
    /// 等价直接给 `base.textColor` 赋值。
    /// - Parameter color: 文字颜色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func textColor(_ color: UIColor?) -> Chain<Base> {
        base.textColor = color
        return self
    }

    /// 设置文字对齐方式。
    ///
    /// 等价直接给 `base.textAlignment` 赋值。
    /// - Parameter alignment: 对齐方式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func textAlignment(_ alignment: NSTextAlignment) -> Chain<Base> {
        base.textAlignment = alignment
        return self
    }

    /// 设置是否可编辑。
    ///
    /// 等价直接给 `base.isEditable` 赋值，设为 false 即变为只读。
    /// - Parameter editable: 是否可编辑。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isEditable(_ editable: Bool) -> Chain<Base> {
        base.isEditable = editable
        return self
    }

    /// 设置是否可选中文本。
    ///
    /// 等价直接给 `base.isSelectable` 赋值。
    /// - Parameter selectable: 是否可选中。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isSelectable(_ selectable: Bool) -> Chain<Base> {
        base.isSelectable = selectable
        return self
    }

    /// 设置自动识别的内容类型。
    ///
    /// 等价直接给 `base.dataDetectorTypes` 赋值，如链接、电话号码等。
    /// - Parameter types: 识别类型集合。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func dataDetectorTypes(_ types: UIDataDetectorTypes) -> Chain<Base> {
        base.dataDetectorTypes = types
        return self
    }

    /// 设置是否允许编辑富文本属性。
    ///
    /// 等价直接给 `base.allowsEditingTextAttributes` 赋值。
    /// - Parameter allows: 是否允许编辑富文本属性。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func allowsEditingTextAttributes(_ allows: Bool) -> Chain<Base> {
        base.allowsEditingTextAttributes = allows
        return self
    }

    /// 设置输入中的富文本属性。
    ///
    /// 注意：UITextView.typingAttributes 是非可选 `[Key: Any]`（与 UITextField 的可选版不同）。
    /// - Parameter attributes: 输入属性字典。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func typingAttributes(_ attributes: [NSAttributedString.Key: Any]) -> Chain<Base> {
        base.typingAttributes = attributes
        return self
    }

    // MARK: - 键盘（UITextInputTraits）

    /// 设置键盘右下角回车键样式。
    ///
    /// 等价直接给 `base.returnKeyType` 赋值，如 `.done` / `.search`。
    /// - Parameter type: 回车键样式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func returnKeyType(_ type: UIReturnKeyType) -> Chain<Base> {
        base.returnKeyType = type
        return self
    }

    /// 设置键盘类型。
    ///
    /// 等价直接给 `base.keyboardType` 赋值，如 `.numberPad` / `.emailAddress`。
    /// - Parameter type: 键盘类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func keyboardType(_ type: UIKeyboardType) -> Chain<Base> {
        base.keyboardType = type
        return self
    }

    /// 设置键盘外观。
    ///
    /// 等价直接给 `base.keyboardAppearance` 赋值，控制明暗主题。
    /// - Parameter appearance: 键盘外观。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func keyboardAppearance(_ appearance: UIKeyboardAppearance) -> Chain<Base> {
        base.keyboardAppearance = appearance
        return self
    }

    /// 设置自动首字母大写。
    ///
    /// 等价直接给 `base.autocapitalizationType` 赋值。
    /// - Parameter type: 自动大写类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func autocapitalizationType(_ type: UITextAutocapitalizationType) -> Chain<Base> {
        base.autocapitalizationType = type
        return self
    }

    /// 设置自动纠错。
    ///
    /// 等价直接给 `base.autocorrectionType` 赋值，`.no` 可关闭纠错。
    /// - Parameter type: 自动纠错类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func autocorrectionType(_ type: UITextAutocorrectionType) -> Chain<Base> {
        base.autocorrectionType = type
        return self
    }

    /// 设置拼写检查。
    ///
    /// 等价直接给 `base.spellCheckingType` 赋值。
    /// - Parameter type: 拼写检查类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func spellCheckingType(_ type: UITextSpellCheckingType) -> Chain<Base> {
        base.spellCheckingType = type
        return self
    }

    /// 设置智能引号。
    ///
    /// 等价直接给 `base.smartQuotesType` 赋值。
    /// - Parameter type: 智能引号类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func smartQuotesType(_ type: UITextSmartQuotesType) -> Chain<Base> {
        base.smartQuotesType = type
        return self
    }

    /// 设置智能破折号。
    ///
    /// 等价直接给 `base.smartDashesType` 赋值。
    /// - Parameter type: 智能破折号类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func smartDashesType(_ type: UITextSmartDashesType) -> Chain<Base> {
        base.smartDashesType = type
        return self
    }

    /// 设置智能插入/删除。
    ///
    /// 等价直接给 `base.smartInsertDeleteType` 赋值。
    /// - Parameter type: 智能插入/删除类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func smartInsertDeleteType(_ type: UITextSmartInsertDeleteType) -> Chain<Base> {
        base.smartInsertDeleteType = type
        return self
    }

    /// 设置无内容时是否禁用回车键。
    ///
    /// 等价直接给 `base.enablesReturnKeyAutomatically` 赋值。
    /// - Parameter enables: 是否自动禁用回车键。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func enablesReturnKeyAutomatically(_ enables: Bool) -> Chain<Base> {
        base.enablesReturnKeyAutomatically = enables
        return self
    }

    /// 设置是否为安全输入（如密码）。
    ///
    /// 等价直接给 `base.isSecureTextEntry` 赋值。
    /// - Parameter secure: 是否安全输入。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isSecureTextEntry(_ secure: Bool) -> Chain<Base> {
        base.isSecureTextEntry = secure
        return self
    }

    /// 设置文本视图代理。
    ///
    /// 代理对象须遵循 `UITextViewDelegate`。注意代理是弱引用。
    /// - Parameter delegate: 文本视图代理。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func delegate(_ delegate: UITextViewDelegate?) -> Chain<Base> {
        base.delegate = delegate
        return self
    }

    // MARK: - 自定义输入面板（替代键盘）

    /// 自定义输入面板替代系统键盘。
    ///
    /// 设为非 nil 后聚焦不弹系统键盘（等同 `base.inputView`）。
    /// - Parameter view: 自定义输入面板。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func inputView(_ view: UIView?) -> Chain<Base> {
        base.inputView = view
        return self
    }

    /// 设置键盘上方的工具条。
    ///
    /// 等同 `base.inputAccessoryView`。
    /// - Parameter view: 工具条视图。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func inputAccessoryView(_ view: UIView?) -> Chain<Base> {
        base.inputAccessoryView = view
        return self
    }
}