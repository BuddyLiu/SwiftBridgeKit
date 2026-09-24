//
//  Chain+UIImageView.swift
//  SwiftChainKit
//
//  图片显示：单图/高亮图/动画组、SF Symbol 快捷入口、图标配色等
//  （contentMode / tintColor / isHidden 等来自 UIView 基座扩展）。

import UIKit

/// UIImageView 链式设置：单图/高亮图/动画组、SF Symbol 快捷入口与符号配置。
///
/// `contentMode` / `tintColor` / `isHidden` 等来自 UIView 基座扩展。
public extension Chain where Base: UIImageView {

    /// 设置普通状态显示的图片。
    ///
    /// 等价直接给 `base.image` 赋值。
    /// - Parameters:
    ///   - image: 新图片，传 `nil` 清空。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func image(_ image: UIImage?) -> Chain<Base> {
        base.image = image
        return self
    }

    /// 设置高亮态显示的图片。
    ///
    /// 等价直接给 `base.highlightedImage` 赋值，配合 `isHighlighted(true)` 使用。
    /// - Parameters:
    ///   - image: 高亮态图片，传 `nil` 清空。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func highlightedImage(_ image: UIImage?) -> Chain<Base> {
        base.highlightedImage = image
        return self
    }

    /// SF Symbol 快捷入口：`symbol("pencil")` 等价 `image(UIImage(systemName: "pencil"))`。
    ///
    /// - Parameters:
    ///   - name: SF Symbol 名称，传 `nil` 清空图片。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func symbol(_ name: String?) -> Chain<Base> {
        base.image = name.flatMap { UIImage(systemName: $0) }
        return self
    }

    /// 设置高亮态。
    ///
    /// 打开时显示 `highlightedImage`，并可用 `highlightedAnimationImages` 播放高亮动画。
    /// - Parameters:
    ///   - highlighted: 是否高亮。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isHighlighted(_ highlighted: Bool) -> Chain<Base> {
        base.isHighlighted = highlighted
        return self
    }

    // MARK: - 动画帧（animating 状态机）

    /// 设置动画帧图片数组。
    ///
    /// 配合 `animationDuration` / `animationRepeatCount` 设置播放参数，
    /// 随后用 `animating(true)` 开始播放。
    /// - Parameters:
    ///   - images: 动画帧数组，传 `nil` 清空。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func animationImages(_ images: [UIImage]?) -> Chain<Base> {
        base.animationImages = images
        return self
    }

    /// 设置高亮态动画帧图片数组。
    ///
    /// 高亮状态下播放的动画帧，配合 `isHighlighted(true)` 使用。
    /// - Parameters:
    ///   - images: 高亮动画帧数组。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func highlightedAnimationImages(_ images: [UIImage]?) -> Chain<Base> {
        base.highlightedAnimationImages = images
        return self
    }

    /// 设置动画播放一轮的时长（秒）。
    ///
    /// 等价直接给 `base.animationDuration` 赋值。
    /// - Parameters:
    ///   - duration: 完整播放一轮的秒数。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func animationDuration(_ duration: TimeInterval) -> Chain<Base> {
        base.animationDuration = duration
        return self
    }

    /// 设置动画重复播放次数。
    ///
    /// 等价直接给 `base.animationRepeatCount` 赋值。
    /// - Parameters:
    ///   - count: 重复次数，`0` 表示无限循环。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func animationRepeatCount(_ count: Int) -> Chain<Base> {
        base.animationRepeatCount = count
        return self
    }

    /// 属性式开关：`animating(true)` 等价 `startAnimating()`，`false` 等价 `stopAnimating()`。
    ///
    /// - Parameters:
    ///   - animated: 是否播放动画。
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

    /// 设置 SF Symbol 符号配置（尺寸/权重/渲染模式）。
    ///
    /// 例如 `preferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 18))`。
    /// - Parameters:
    ///   - configuration: 符号配置，传 `nil` 使用默认配置。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func preferredSymbolConfiguration(_ configuration: UIImage.SymbolConfiguration?) -> Chain<Base> {
        base.preferredSymbolConfiguration = configuration
        return self
    }
}