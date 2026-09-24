//
//  Chain+UILabel.swift
//  SwiftChainKit
//
//  文字显示：内容、字体、配色、对齐、换行/缩放策略 —— 常见展示需求基本都在这。

import UIKit

/// UILabel 链式设置：文字内容、字体、配色、对齐、行数/换行与缩放策略。
public extension Chain where Base: UILabel {

    /// 设置文本内容。
    ///
    /// 等价直接给 `base.text` 赋值。
    /// - Parameters:
    ///   - text: 新文本，传 `nil` 清空。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func text(_ text: String?) -> Chain<Base> {
        base.text = text
        return self
    }

    /// 设置富文本属性文本。
    ///
    /// 等价直接给 `base.attributedText` 赋值；部分样式（字体/颜色等）以属性串设置为准。
    /// - Parameters:
    ///   - text: 属性文本，传 `nil` 清空。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func attributedText(_ text: NSAttributedString?) -> Chain<Base> {
        base.attributedText = text
        return self
    }

    /// 设置字体。
    ///
    /// 等价直接给 `base.font` 赋值，例如 `.systemFont(ofSize: 16)`。
    /// - Parameters:
    ///   - font: 新字体。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func font(_ font: UIFont) -> Chain<Base> {
        base.font = font
        return self
    }

    /// 设置文本颜色。
    ///
    /// 等价直接给 `base.textColor` 赋值。
    /// - Parameters:
    ///   - color: 新颜色，传 `nil` 使用默认色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func textColor(_ color: UIColor?) -> Chain<Base> {
        base.textColor = color
        return self
    }

    /// 设置高亮态文本颜色。
    ///
    /// 高亮态文本配合 `isHighlighted(true)` 展示；等价直接给 `base.highlightedTextColor` 赋值。
    /// - Parameters:
    ///   - color: 高亮态颜色，传 `nil` 恢复默认。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func highlightedTextColor(_ color: UIColor?) -> Chain<Base> {
        base.highlightedTextColor = color
        return self
    }

    /// 设置文本水平对齐方式。
    ///
    /// 等价直接给 `base.textAlignment` 赋值，例如 `.center` / `.left` / `.right`。
    /// - Parameters:
    ///   - alignment: 对齐方式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func textAlignment(_ alignment: NSTextAlignment) -> Chain<Base> {
        base.textAlignment = alignment
        return self
    }

    /// 设置最大显示行数，`0` 表示不限制。
    ///
    /// 等价直接给 `base.numberOfLines` 赋值；大于 `1` 时生效于自动换行布局。
    /// - Parameters:
    ///   - lines: 最大行数，`0` 为无限行。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func numberOfLines(_ lines: Int) -> Chain<Base> {
        base.numberOfLines = lines
        return self
    }

    /// 设置换行/截断模式。
    ///
    /// 等价直接给 `base.lineBreakMode` 赋值；单行截断（如 `.byTruncatingTail`）
    /// 需配合 `numberOfLines(1)` 使用。
    /// - Parameters:
    ///   - mode: 换行或截断模式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func lineBreakMode(_ mode: NSLineBreakMode) -> Chain<Base> {
        base.lineBreakMode = mode
        return self
    }

    /// 设置高亮态。
    ///
    /// 高亮态下标题使用 `highlightedTextColor` 指定的颜色显示。
    /// - Parameters:
    ///   - highlighted: 是否高亮。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isHighlighted(_ highlighted: Bool) -> Chain<Base> {
        base.isHighlighted = highlighted
        return self
    }

    /// 设置是否可用。
    ///
    /// 等价直接给 `base.isEnabled` 赋值；禁用后文本通常显示为灰色。
    /// - Parameters:
    ///   - enabled: 是否可用。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isEnabled(_ enabled: Bool) -> Chain<Base> {
        base.isEnabled = enabled
        return self
    }

    /// 设置文本垂直基线对齐调整方式。
    ///
    /// 字号被缩放时，决定文本相对基线如何对齐，如 `.alignBaselines` / `.alignCenters`。
    /// - Parameters:
    ///   - adjustment: 基线调整方式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func baselineAdjustment(_ adjustment: UIBaselineAdjustment) -> Chain<Base> {
        base.baselineAdjustment = adjustment
        return self
    }

    /// 一行放不下时自动缩小字号以适配宽度。
    ///
    /// 需配合 `minimumScaleFactor` 设置缩小的下限，并保持 `numberOfLines(1)`。
    /// - Parameters:
    ///   - adjusts: 是否允许自适应缩小字号。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func adjustsFontSizeToFitWidth(_ adjusts: Bool) -> Chain<Base> {
        base.adjustsFontSizeToFitWidth = adjusts
        return self
    }

    /// 设置自适应缩小时的最小缩放因子。
    ///
    /// 配合 `adjustsFontSizeToFitWidth(true)` 使用；`0.1` 表示最小可缩到 10%。
    /// - Parameters:
    ///   - factor: 最小缩放比例（0.0 ~ 1.0）。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func minimumScaleFactor(_ factor: CGFloat) -> Chain<Base> {
        base.minimumScaleFactor = factor
        return self
    }

    /// 支持 Dynamic Type：字体随系统「文字大小」设置缩放。
    ///
    /// 等价直接给 `base.adjustsFontForContentSizeCategory` 赋值，通常使用动态字体生效。
    /// - Parameters:
    ///   - adjusts: 是否跟随系统文字大小。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func adjustsFontForContentSizeCategory(_ adjusts: Bool) -> Chain<Base> {
        base.adjustsFontForContentSizeCategory = adjusts
        return self
    }

    /// 允许文本在截断时自动收紧字距（默认关闭）。
    ///
    /// 等价直接给 `base.allowsDefaultTighteningForTruncation` 赋值，
    /// 配合字符较多的单行文本使用。
    /// - Parameters:
    ///   - allows: 是否允许自动收紧字距。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func allowsDefaultTighteningForTruncation(_ allows: Bool) -> Chain<Base> {
        base.allowsDefaultTighteningForTruncation = allows
        return self
    }

    /// 设置换行策略。
    ///
    /// 等价直接给 `base.lineBreakStrategy` 赋值，如 `.standard` / `.hangulWordPriority`。
    /// - Parameters:
    ///   - strategy: 换行策略。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func lineBreakStrategy(_ strategy: NSParagraphStyle.LineBreakStrategy) -> Chain<Base> {
        base.lineBreakStrategy = strategy
        return self
    }

    /// 设置文字阴影颜色。
    ///
    /// 通常与 `shadowOffset` 搭配使用；传 `nil` 清除阴影颜色。
    /// - Parameters:
    ///   - color: 阴影颜色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func shadowColor(_ color: UIColor?) -> Chain<Base> {
        base.shadowColor = color
        return self
    }

    /// 设置文字阴影偏移量。
    ///
    /// 默认值为 `CGSize(width: 0, height: -1)`；与 `shadowColor` 搭配使用。
    /// - Parameters:
    ///   - offset: 阴影偏移量。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func shadowOffset(_ offset: CGSize) -> Chain<Base> {
        base.shadowOffset = offset
        return self
    }

    /// 设置多行 Auto Layout 的「理想宽度」。
    ///
    /// 多行 Label 用 Auto Layout 计算固有高度前需先指定理想宽度
    /// （等价给 `base.preferredMaxLayoutWidth` 赋值）。
    /// - Parameters:
    ///   - width: 理想宽度。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func preferredMaxLayoutWidth(_ width: CGFloat) -> Chain<Base> {
        base.preferredMaxLayoutWidth = width
        return self
    }
}