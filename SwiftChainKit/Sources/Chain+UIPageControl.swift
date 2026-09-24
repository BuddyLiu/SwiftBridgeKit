//
//  Chain+UIPageControl.swift
//  SwiftChainKit
//
//  页码圆点：页数/当前页/颜色/单页隐藏。配合分页滚动容器使用。

import UIKit

/// 页码圆点配置链：页数/当前页/颜色/单页隐藏，含 iOS 14+ 扩充。
///
/// 配合分页滚动容器（`UIScrollView` + `isPagingEnabled`）使用。
public extension Chain where Base: UIPageControl {

    /// 单页时是否自动隐藏页码（默认 false）。
    /// - Parameter hides: 传 true 在仅一页时隐藏圆点。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func hidesForSinglePage(_ hides: Bool) -> Chain<Base> {
        base.hidesForSinglePage = hides
        return self
    }

    /// 设置非当前页圆点颜色。
    /// - Parameter color: 圆点颜色，可传 nil 恢复默认。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func pageIndicatorTintColor(_ color: UIColor?) -> Chain<Base> {
        base.pageIndicatorTintColor = color
        return self
    }

    /// 设置当前页圆点颜色。
    /// - Parameter color: 当前页圆点颜色，可传 nil 恢复默认。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func currentPageIndicatorTintColor(_ color: UIColor?) -> Chain<Base> {
        base.currentPageIndicatorTintColor = color
        return self
    }

    /// 设置总页数。
    /// - Parameter pages: 页数，需与滚动容器内容页数保持一致。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func numberOfPages(_ pages: Int) -> Chain<Base> {
        base.numberOfPages = pages
        return self
    }

    /// 设置当前页索引（从 0 开始）。
    /// - Parameter page: 当前页索引，越界值会被系统钳制。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func currentPage(_ page: Int) -> Chain<Base> {
        base.currentPage = page
        return self
    }

    // MARK: iOS 14+ 扩充

    /// 单页是否允许点按连续翻页（iOS 14+，默认 true）。
    /// - Parameter allows: 传 false 时单页长按/连点不连续换页。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func allowsContinuousInteraction(_ allows: Bool) -> Chain<Base> {
        base.allowsContinuousInteraction = allows
        return self
    }

    /// 指示器底色形态：`.automatic` / `.prominent` / `.minimal`（iOS 14+）。
    /// - Parameter style: 圆点底色样式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func backgroundStyle(_ style: UIPageControl.BackgroundStyle) -> Chain<Base> {
        base.backgroundStyle = style
        return self
    }

    /// 全局指示器图片（iOS 14+，未按页指定时统一使用）。
    /// - Parameter image: 指示器图片，可传 nil 恢复圆点。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func preferredIndicatorImage(_ image: UIImage?) -> Chain<Base> {
        base.preferredIndicatorImage = image
        return self
    }

    /// 按页指定指示器图片：`indicatorImage(icon, forPage: 2)`（iOS 14+）。
    ///
    /// 等价 `UIPageControl.setIndicatorImage(_:forPage:)`。
    /// - Parameters:
    ///   - image: 该页指示器图片，可传 nil 恢复圆点。
    ///   - page: 目标页码。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func indicatorImage(_ image: UIImage?, forPage page: Int) -> Chain<Base> {
        base.setIndicatorImage(image, forPage: page)
        return self
    }
}