//
//  Chain+UIActivityIndicatorView.swift
//  SwiftChainKit
//
//  转圈：创建样式 + 展示开关；起停用属性式 `animating(_:)`，不再留两段式 start/stop。

import UIKit

/// 转圈工厂入口：`UIActivityIndicatorView.chain(style:)` 以指定样式创建并进链。
public extension UIActivityIndicatorView {
    /// 以指定样式创建 `UIActivityIndicatorView` 进入链式设置。
    /// - Parameters:
    ///   - style: 指示器样式（`.medium` / `.large` 等）。
    /// - Returns: 返回可链式设置的 `UIActivityIndicatorView` 链。
    @MainActor
    static func chain(style: UIActivityIndicatorView.Style) -> Chain<UIActivityIndicatorView> {
        Chain(UIActivityIndicatorView(style: style))
    }
}

/// 转圈配置链：展示开关与颜色；起停用属性式 `animating(_:)`，不再留两段式 start/stop。
public extension Chain where Base: UIActivityIndicatorView {

    /// 停止时是否自动隐藏（默认 true）。
    /// - Parameter hides: 传 false 使停止时仍占位可见。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func hidesWhenStopped(_ hides: Bool) -> Chain<Base> {
        base.hidesWhenStopped = hides
        return self
    }

    /// 设置转圈颜色。
    /// - Parameter color: 转圈指示器颜色，可传 nil 恢复默认。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func color(_ color: UIColor?) -> Chain<Base> {
        base.color = color
        return self
    }

    /// 属性式开关：`animating(true)` 等价 `startAnimating()`，`false` 等价 `stopAnimating()`。
    /// - Parameter animated: 传 true 开始转动，false 停止。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func animating(_ animated: Bool) -> Chain<Base> {
        if animated {
            base.startAnimating()
        } else {
            base.stopAnimating()
        }
        return self
    }
}