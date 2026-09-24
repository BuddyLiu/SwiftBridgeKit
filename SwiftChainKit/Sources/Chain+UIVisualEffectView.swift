//
//  Chain+UIVisualEffectView.swift
//  SwiftChainKit
//
//  毛玻璃容器：`effect(UIBlurEffect(style: .systemThinMaterial))` 即出磨砂底。

import UIKit

/// 毛玻璃容器链式设置：`effect(UIBlurEffect(style: .systemThinMaterial))` 即出磨砂底。
public extension Chain where Base: UIVisualEffectView {

    /// 设置视觉效果（毛玻璃 / 高亮）。
    ///
    /// 常用写法：`effect(UIBlurEffect(style: .systemThinMaterial))`；
    /// 需要内容跟随毛玻璃做立体高亮时改用 `UIVibrancyEffect`。
    /// - Parameter effect: 视觉效果；传 `nil` 清除现有效果。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func effect(_ effect: UIVisualEffect?) -> Chain<Base> {
        base.effect = effect
        return self
    }
}