//
//  Chain+UIScrollView.swift
//  SwiftChainKit
//
//  滚动容器：内容区、偏移、内边距、弹跳/翻页/指示条、缩放、键盘行为，以及 delegate。
//  分页轮播、列表、集合全都从这一层继承。

import UIKit

/// `UIScrollView` 链式设置：滚动内容、偏移、内边距、弹跳/翻页、缩放与 delegate。
///
/// 分页轮播、列表、集合全都从这一层继承公共设置方法。
public extension Chain where Base: UIScrollView {

    /// 设置是否允许滚动。
    ///
    /// 等价直接给 `base.isScrollEnabled` 赋值。
    /// - Parameter enabled: 是否允许滚动。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isScrollEnabled(_ enabled: Bool) -> Chain<Base> {
        base.isScrollEnabled = enabled
        return self
    }

    /// 设置内容区尺寸。
    ///
    /// 等价直接给 `base.contentSize` 赋值。
    /// - Parameter size: 内容区尺寸。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func contentSize(_ size: CGSize) -> Chain<Base> {
        base.contentSize = size
        return self
    }

    /// 设置内容偏移（不带动画）。
    ///
    /// 等价直接给 `base.contentOffset` 赋值。
    /// - Parameter offset: 内容偏移点。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func contentOffset(_ offset: CGPoint) -> Chain<Base> {
        base.contentOffset = offset
        return self
    }

    /// 设置内容偏移，可选带动画。
    ///
    /// 等价 `base.setContentOffset(offset, animated: animated)`。
    /// - Parameters:
    ///   - offset: 内容偏移点。
    ///   - animated: 是否带动画。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func contentOffset(_ offset: CGPoint, animated: Bool) -> Chain<Base> {
        base.setContentOffset(offset, animated: animated)
        return self
    }

    /// 设置内容内边距。
    ///
    /// 等价直接给 `base.contentInset` 赋值。
    /// - Parameter inset: 内容内边距。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func contentInset(_ inset: UIEdgeInsets) -> Chain<Base> {
        base.contentInset = inset
        return self
    }

    /// 设置滚动条内边距。
    ///
    /// 等价直接给 `base.scrollIndicatorInsets` 赋值。
    /// - Parameter insets: 滚动条内边距。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func scrollIndicatorInsets(_ insets: UIEdgeInsets) -> Chain<Base> {
        base.scrollIndicatorInsets = insets
        return self
    }

    /// 设置竖向滚动条内边距（iOS 11.3+ 拆分出的独立项，覆盖 `scrollIndicatorInsets` 的竖轴）。
    ///
    /// 等价直接给 `base.verticalScrollIndicatorInsets` 赋值。
    /// - Parameter insets: 竖向滚动条内边距。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func verticalScrollIndicatorInsets(_ insets: UIEdgeInsets) -> Chain<Base> {
        base.verticalScrollIndicatorInsets = insets
        return self
    }

    /// 设置横向滚动条内边距（iOS 11.3+ 拆分出的独立项，覆盖 `scrollIndicatorInsets` 的横轴）。
    ///
    /// 等价直接给 `base.horizontalScrollIndicatorInsets` 赋值。
    /// - Parameter insets: 横向滚动条内边距。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func horizontalScrollIndicatorInsets(_ insets: UIEdgeInsets) -> Chain<Base> {
        base.horizontalScrollIndicatorInsets = insets
        return self
    }

    /// 设置滚动条样式。
    ///
    /// 等价直接给 `base.indicatorStyle` 赋值。
    /// - Parameter style: 滚动条样式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func indicatorStyle(_ style: UIScrollView.IndicatorStyle) -> Chain<Base> {
        base.indicatorStyle = style
        return self
    }

    /// 设置是否分页滚动。
    ///
    /// 等价直接给 `base.isPagingEnabled` 赋值。
    /// - Parameter paging: 是否分页。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isPagingEnabled(_ paging: Bool) -> Chain<Base> {
        base.isPagingEnabled = paging
        return self
    }

    /// 设置是否开启弹性回弹。
    ///
    /// 等价直接给 `base.bounces` 赋值。
    /// - Parameter bounces: 是否弹性回弹。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func bounces(_ bounces: Bool) -> Chain<Base> {
        base.bounces = bounces
        return self
    }

    /// 设置缩放时是否弹性回弹。
    ///
    /// 等价直接给 `base.bouncesZoom` 赋值。
    /// - Parameter bounces: 缩放时是否弹性回弹。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func bouncesZoom(_ bounces: Bool) -> Chain<Base> {
        base.bouncesZoom = bounces
        return self
    }

    /// 设置内容不满一屏时横向是否仍可回弹。
    ///
    /// 等价直接给 `base.alwaysBounceHorizontal` 赋值。
    /// - Parameter bounces: 内容不满一屏时横向是否仍可回弹。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func alwaysBounceHorizontal(_ bounces: Bool) -> Chain<Base> {
        base.alwaysBounceHorizontal = bounces
        return self
    }

    /// 设置内容不满一屏时纵向是否仍可回弹。
    ///
    /// 等价直接给 `base.alwaysBounceVertical` 赋值。
    /// - Parameter bounces: 内容不满一屏时纵向是否仍可回弹。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func alwaysBounceVertical(_ bounces: Bool) -> Chain<Base> {
        base.alwaysBounceVertical = bounces
        return self
    }

    /// 设置是否显示横向滚动条。
    ///
    /// 等价直接给 `base.showsHorizontalScrollIndicator` 赋值。
    /// - Parameter shows: 是否显示。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func showsHorizontalScrollIndicator(_ shows: Bool) -> Chain<Base> {
        base.showsHorizontalScrollIndicator = shows
        return self
    }

    /// 设置是否显示纵向滚动条。
    ///
    /// 等价直接给 `base.showsVerticalScrollIndicator` 赋值。
    /// - Parameter shows: 是否显示。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func showsVerticalScrollIndicator(_ shows: Bool) -> Chain<Base> {
        base.showsVerticalScrollIndicator = shows
        return self
    }

    /// 设置是否锁定滚动方向（沿一轴滚动时不产生斜向）。
    ///
    /// 等价直接给 `base.isDirectionalLockEnabled` 赋值。
    /// - Parameter enabled: 是否锁定方向。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isDirectionalLockEnabled(_ enabled: Bool) -> Chain<Base> {
        base.isDirectionalLockEnabled = enabled
        return self
    }

    /// 设置是否延迟内容触摸。
    ///
    /// 等价直接给 `base.delaysContentTouches` 赋值。开启后触摸先做滚动判定。
    /// - Parameter delays: 是否延迟内容触摸。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func delaysContentTouches(_ delays: Bool) -> Chain<Base> {
        base.delaysContentTouches = delays
        return self
    }

    /// 设置拖动时能否取消内容上的触摸。
    ///
    /// 等价直接给 `base.canCancelContentTouches` 赋值。
    /// - Parameter cancels: 能否取消内容触摸。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func canCancelContentTouches(_ cancels: Bool) -> Chain<Base> {
        base.canCancelContentTouches = cancels
        return self
    }

    /// 设置点击状态栏时是否滚动回顶部。
    ///
    /// 等价直接给 `base.scrollsToTop` 赋值。
    /// - Parameter scrolls: 是否允许滚动回顶部。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func scrollsToTop(_ scrolls: Bool) -> Chain<Base> {
        base.scrollsToTop = scrolls
        return self
    }

    /// 设置惯性减速速率。
    ///
    /// 等价直接给 `base.decelerationRate` 赋值，可用 `.normal` / `.fast`。
    /// - Parameter rate: 减速速率。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func decelerationRate(_ rate: UIScrollView.DecelerationRate) -> Chain<Base> {
        base.decelerationRate = rate
        return self
    }

    // MARK: - 缩放

    /// 设置当前缩放比例。
    ///
    /// 等价直接给 `base.zoomScale` 赋值。
    /// - Parameter scale: 缩放比例。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func zoomScale(_ scale: CGFloat) -> Chain<Base> {
        base.zoomScale = scale
        return self
    }

    /// 设置最小缩放比例。
    ///
    /// 等价直接给 `base.minimumZoomScale` 赋值。
    /// - Parameter scale: 最小缩放比例。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func minimumZoomScale(_ scale: CGFloat) -> Chain<Base> {
        base.minimumZoomScale = scale
        return self
    }

    /// 设置最大缩放比例。
    ///
    /// 等价直接给 `base.maximumZoomScale` 赋值。
    /// - Parameter scale: 最大缩放比例。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func maximumZoomScale(_ scale: CGFloat) -> Chain<Base> {
        base.maximumZoomScale = scale
        return self
    }

    // MARK: - 系统集成

    /// SafeArea / 内容区联动：`.automatic` / `.never` / `.always` / `.scrollableAxes`。
    ///
    /// 等价直接给 `base.contentInsetAdjustmentBehavior` 赋值。
    /// - Parameter behavior: 内容区调整行为。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func contentInsetAdjustmentBehavior(_ behavior: UIScrollView.ContentInsetAdjustmentBehavior) -> Chain<Base> {
        base.contentInsetAdjustmentBehavior = behavior
        return self
    }

    /// 设置拖拽/滚动时键盘的收起方式。
    ///
    /// 等价直接给 `base.keyboardDismissMode` 赋值。常见取值 `.onDrag`：拖动时收起键盘。
    /// - Parameter mode: 键盘收起模式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func keyboardDismissMode(_ mode: UIScrollView.KeyboardDismissMode) -> Chain<Base> {
        base.keyboardDismissMode = mode
        return self
    }

    /// 设置下拉刷新控件。
    ///
    /// 等价直接给 `base.refreshControl` 赋值，传 nil 移除。
    /// - Parameter refreshControl: 刷新控件。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func refreshControl(_ refreshControl: UIRefreshControl?) -> Chain<Base> {
        base.refreshControl = refreshControl
        return self
    }

    /// 设置滚动代理。
    ///
    /// 代理对象须遵循 `UIScrollViewDelegate`，弱引用，需在使用方持有。
    /// - Parameter delegate: 滚动代理。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func delegate(_ delegate: UIScrollViewDelegate?) -> Chain<Base> {
        base.delegate = delegate
        return self
    }
}