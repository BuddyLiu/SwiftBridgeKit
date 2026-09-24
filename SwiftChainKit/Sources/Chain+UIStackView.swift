//
//  Chain+UIStackView.swift
//  SwiftChainKit
//
//  布局栈：轴/对齐/分布/间距/内边距；arrangedSubviews 追加与 customSpacing 已收进来，
//  axis 等内容继承自 UIView 基座。

import UIKit

/// UIStackView 链式工厂入口。
public extension UIStackView {
    /// 工厂：创建排列了指定子视图的 `UIStackView` 并返回可链式设置的链。
    ///
    /// `UIStackView.chain(arrangedSubviews: [icon, label])...`，
    /// 等价 ObjC 时代 `UIStackView(arrangedSubviews:)` 后再逐个配置。
    /// - Parameters:
    ///   - arrangedSubviews: 初始排列子视图数组。
    /// - Returns: 返回可链式设置的 UIStackView 链。
    @MainActor
    static func chain(arrangedSubviews: [UIView]) -> Chain<UIStackView> {
        Chain(UIStackView(arrangedSubviews: arrangedSubviews))
    }
}

/// UIStackView 链式设置：轴/对齐/分布/间距/内边距与排列子视图管理。
public extension Chain where Base: UIStackView {

    /// 设置主轴方向。
    ///
    /// 等价直接给 `base.axis` 赋值；决定子视图沿横向（`.horizontal`）还是
    /// 纵向（`.vertical`）排列。
    /// - Parameters:
    ///   - axis: 主轴方向。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func axis(_ axis: NSLayoutConstraint.Axis) -> Chain<Base> {
        base.axis = axis
        return self
    }

    /// 设置子视图在副轴上的对齐方式。
    ///
    /// 等价直接给 `base.alignment` 赋值，如 `.fill` / `.leading` / `.top` / `.center`。
    /// - Parameters:
    ///   - alignment: 对齐方式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func alignment(_ alignment: UIStackView.Alignment) -> Chain<Base> {
        base.alignment = alignment
        return self
    }

    /// 设置子视图沿主轴的分布策略。
    ///
    /// 等价直接给 `base.distribution` 赋值，如 `.fill` / `.fillEqually` /
    /// `.fillProportionally` / `.equalSpacing`。
    /// - Parameters:
    ///   - distribution: 分布策略。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func distribution(_ distribution: UIStackView.Distribution) -> Chain<Base> {
        base.distribution = distribution
        return self
    }

    /// 设置相邻排列子视图之间的间距。
    ///
    /// 等价直接给 `base.spacing` 赋值。
    /// - Parameters:
    ///   - spacing: 间距值。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func spacing(_ spacing: CGFloat) -> Chain<Base> {
        base.spacing = spacing
        return self
    }

    /// 单独设置某个子视图之后的间距。
    ///
    /// `customSpacing(20, after: titleLabel)`：给 titleLabel 与其下一个子视图之间
    /// 指定自定义间距（优先级高于全局 `spacing`）。
    /// - Parameters:
    ///   - spacing: 自定义间距值。
    ///   - view: 其后间距被修改的排列子视图。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func customSpacing(_ spacing: CGFloat, after view: UIView) -> Chain<Base> {
        base.setCustomSpacing(spacing, after: view)
        return self
    }

    /// 设置排列子视图是否基于基线对齐来计算位置。
    ///
    /// 开启后对齐依据从 frame 改为文本基线，适合文字高度不一致的场景。
    /// - Parameters:
    ///   - relative: 是否使用基线相对排列。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isBaselineRelativeArrangement(_ relative: Bool) -> Chain<Base> {
        base.isBaselineRelativeArrangement = relative
        return self
    }

    /// 设置排列子视图是否相对布局边距排列。
    ///
    /// 开启后子视图相对 `directionalLayoutMargins` 定义的边距排列。
    /// - Parameters:
    ///   - relative: 是否使用布局边距相对排列。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isLayoutMarginsRelativeArrangement(_ relative: Bool) -> Chain<Base> {
        base.isLayoutMarginsRelativeArrangement = relative
        return self
    }

    /// 设置方向性布局边距（随阅读方向翻转）。
    ///
    /// 需配合 `isLayoutMarginsRelativeArrangement(true)` 生效。
    /// - Parameters:
    ///   - insets: 四周边距。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func directionalLayoutMargins(_ insets: NSDirectionalEdgeInsets) -> Chain<Base> {
        base.directionalLayoutMargins = insets
        return self
    }

    /// 批量追加排列子视图（等价逐个 `addArrangedSubview`）。
    ///
    /// - Parameters:
    ///   - views: 要追加的视图数组。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func arrangedSubviews(_ views: [UIView]) -> Chain<Base> {
        views.forEach { base.addArrangedSubview($0) }
        return self
    }

    /// 在指定下标插入排列子视图：`insertArrangedSubview(view, at: 0)`。
    ///
    /// 等价调用 `base.insertArrangedSubview(_:at:)`。
    /// - Parameters:
    ///   - view: 要插入的视图。
    ///   - index: 插入位置下标。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func insertArrangedSubview(_ view: UIView, at index: Int) -> Chain<Base> {
        base.insertArrangedSubview(view, at: index)
        return self
    }

    /// 从排列中移除子视图（等价 `base.removeArrangedSubview`）。
    ///
    /// 注意：仅从排列中移除，若需彻底移除还需一并解除其约束。
    /// - Parameters:
    ///   - view: 要移除的视图。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func removeArrangedSubview(_ view: UIView) -> Chain<Base> {
        base.removeArrangedSubview(view)
        return self
    }
}