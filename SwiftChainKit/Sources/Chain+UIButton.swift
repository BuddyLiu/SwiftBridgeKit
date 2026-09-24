//
//  Chain+UIButton.swift
//  SwiftChainKit
//
//  按钮按类型创建走静态工厂 `UIButton.chain(type:)`；文字/图标/字体/内边距都收进来，
//  不再需要 `button.titleLabel?.font = ...` 这种「先拿再改」的两段式。
//  isEnabled / isSelected / isHighlighted / contentAlignment 来自 UIControl 基座扩展。

import UIKit

/// UIButton 链式工厂入口。
public extension UIButton {
    /// 工厂：创建 `UIButton` 并返回可链式设置的链。
    ///
    /// `UIButton.chain(type: .system).title("确定")...build()`。
    /// - Parameters:
    ///   - buttonType: 按钮类型，默认 `.custom`。
    /// - Returns: 返回可链式设置的 UIButton 链。
    @discardableResult
    @MainActor
    static func chain(type buttonType: UIButton.ButtonType = .custom) -> Chain<UIButton> {
        Chain(UIButton(type: buttonType))
    }
}

/// UIButton 链式设置：文字/图标/字体/内边距；`isEnabled` 等来自 UIControl 基座扩展。
public extension Chain where Base: UIButton {

    /// 设置指定状态下显示的标题。
    ///
    /// 等价直接给 `base.setTitle(title, for: state)`；`state` 用于区分不同控制状态的
    /// 显示，例如 `.normal` / `.highlighted` / `.selected` / `.disabled`。
    /// - Parameters:
    ///   - title: 新标题，传 `nil` 清空指定状态的标题。
    ///   - state: 目标控制状态，默认 `.normal`。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func title(_ title: String?, for state: UIControl.State = .normal) -> Chain<Base> {
        base.setTitle(title, for: state)
        return self
    }

    /// 设置指定状态下显示的富文本标题。
    ///
    /// 等价直接给 `base.setAttributedTitle(title, for: state)`，样式在属性串中统一配置。
    /// - Parameters:
    ///   - title: 属性文本标题，传 `nil` 清空指定状态的标题。
    ///   - state: 目标控制状态，默认 `.normal`。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func attributedTitle(_ title: NSAttributedString?, for state: UIControl.State = .normal) -> Chain<Base> {
        base.setAttributedTitle(title, for: state)
        return self
    }

    /// 设置指定状态下的标题颜色。
    ///
    /// 等价直接给 `base.setTitleColor(color, for: state)`。
    /// - Parameters:
    ///   - color: 标题颜色，传 `nil` 恢复默认。
    ///   - state: 目标控制状态，默认 `.normal`。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func titleColor(_ color: UIColor?, for state: UIControl.State = .normal) -> Chain<Base> {
        base.setTitleColor(color, for: state)
        return self
    }

    /// 设置指定状态下显示的图片。
    ///
    /// 等价直接给 `base.setImage(image, for: state)`。
    /// - Parameters:
    ///   - image: 图标图片，传 `nil` 清空。
    ///   - state: 目标控制状态，默认 `.normal`。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func image(_ image: UIImage?, for state: UIControl.State = .normal) -> Chain<Base> {
        base.setImage(image, for: state)
        return self
    }

    /// SF Symbol 快捷入口：`symbol("checkmark", for: .normal)`。
    ///
    /// 等价直接给 `base.setImage(UIImage(systemName: name), for: state)`。
    /// - Parameters:
    ///   - name: SF Symbol 名称，传 `nil` 清空图片。
    ///   - state: 目标控制状态，默认 `.normal`。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func symbol(_ name: String?, for state: UIControl.State = .normal) -> Chain<Base> {
        base.setImage(name.flatMap { UIImage(systemName: $0) }, for: state)
        return self
    }

    /// 设置指定状态下的背景图片。
    ///
    /// 等价直接给 `base.setBackgroundImage(image, for: state)`。
    /// - Parameters:
    ///   - image: 背景图片，传 `nil` 清空。
    ///   - state: 目标控制状态，默认 `.normal`。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func backgroundImage(_ image: UIImage?, for state: UIControl.State = .normal) -> Chain<Base> {
        base.setBackgroundImage(image, for: state)
        return self
    }

    /// 设置按钮标题字体。
    ///
    /// 写在 `titleLabel` 上的字体（iOS 15 前配置 UIButton 的惯用路径），
    /// 等价 `base.titleLabel?.font = font`。
    /// - Parameters:
    ///   - font: 标题字体。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func font(_ font: UIFont) -> Chain<Base> {
        base.titleLabel?.font = font
        return self
    }
}

// 说明：iOS 15 起 contentEdgeInsets / titleEdgeInsets / imageEdgeInsets /
// adjustsImageWhenHighlighted(_:) / adjustsImageWhenDisabled(_:) / showsTouchWhenHighlighted(_:)
// 均被 UIButtonConfiguration 取代（设置后即弃用告警）。库不收录这些已弃用 API——
// 需要新式内边距/自适应动画的，用 `.configuration(...)` 或 `.also { $0.configuration = ... }`。