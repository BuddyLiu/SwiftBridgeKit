//
//  Chain+UIRefreshControl.swift
//  SwiftChainKit
//
//  下拉刷新：标题/配色 + 属性式 `refreshing(_:)` 开关（两段式 begin/end 收成一个）。

import UIKit

/// 下拉刷新链式设置：富文本标题 + 属性式 `refreshing(_:)` 开关。
/// 把 `beginRefreshing` / `endRefreshing` 两段式调用收成一个布尔属性。
public extension Chain where Base: UIRefreshControl {

    /// 设置下拉提示的富文本标题（可带颜色/字号，区别于纯文本）。
    /// - Parameter title: 标题；`nil` 清除。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func attributedTitle(_ title: NSAttributedString?) -> Chain<Base> {
        base.attributedTitle = title
        return self
    }

    /// 属性式开关：`refreshing(true)` 等价 `beginRefreshing()`，`false` 等价 `endRefreshing()`。
    ///
    /// 注意：`UIRefreshControl` 尚未加入可见层级时 `beginRefreshing()` 不会让指示器
    /// 真正转起来，需先挂到滚动容器（如 `.added(to:)` 或 scroll view 的 `refreshControl`）。
    /// - Parameter refreshing: `true` 开始刷新，`false` 结束。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func refreshing(_ refreshing: Bool) -> Chain<Base> {
        if refreshing {
            base.beginRefreshing()
        } else {
            base.endRefreshing()
        }
        return self
    }
}