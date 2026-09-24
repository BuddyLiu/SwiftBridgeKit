//
//  Chain+UIProgressView.swift
//  SwiftChainKit
//
//  进度条：进度值（可带动画）、前后轨道色、observedProgress 联动。

import UIKit

/// 进度条工厂入口：`UIProgressView.chain(style:)` 以指定样式创建并进链。
public extension UIProgressView {
    /// 以指定样式创建 `UIProgressView` 进入链式设置。
    /// - Parameters:
    ///   - style: 进度条样式，默认 `.default`（另有 `.bar` 用于工具栏等紧凑场景）。
    /// - Returns: 返回可链式设置的 `UIProgressView` 链。
    @MainActor
    static func chain(style: UIProgressView.Style = .default) -> Chain<UIProgressView> {
        Chain(UIProgressView(progressViewStyle: style))
    }
}

/// 进度条配置链：进度值（可带动画）、前后轨道色、observedProgress 联动。
public extension Chain where Base: UIProgressView {

    /// 设置进度值，可带动画（等价 `UIProgressView.setProgress(_:animated:)`）。
    /// - Parameters:
    ///   - progress: 进度值，范围 0.0~1.0。
    ///   - animated: 是否动画过渡，默认 false。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func progress(_ progress: Float, animated: Bool = false) -> Chain<Base> {
        base.setProgress(progress, animated: animated)
        return self
    }

    /// 设置进度条已填充部分的颜色。
    /// - Parameter color: 已填充颜色，可传 nil 恢复默认。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func progressTintColor(_ color: UIColor?) -> Chain<Base> {
        base.progressTintColor = color
        return self
    }

    /// 设置进度条轨道（未填充背景）颜色。
    /// - Parameter color: 轨道颜色，可传 nil 恢复默认。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func trackTintColor(_ color: UIColor?) -> Chain<Base> {
        base.trackTintColor = color
        return self
    }

    /// 与 Progress observation 联动（网络下载等场景）。
    /// - Parameter progress: 被观察的 `Progress`，其 `fractionCompleted` 变化会同步到进度条。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func observedProgress(_ progress: Progress?) -> Chain<Base> {
        base.observedProgress = progress
        return self
    }
}