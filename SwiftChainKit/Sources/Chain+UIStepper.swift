//
//  Chain+UIStepper.swift
//  SwiftChainKit
//
//  步进器：值域/步长/循环/自动连发，以及分段样式两侧按钮与背景图。

import UIKit

/// 步进器链式设置：值域/步长/循环/自动连发，以及分段样式两侧按钮与背景图。
///
/// 注意：UIStepper 没有 UISlider 那套 `minimumValueImage` / `maximumValueImage`，
/// 分段外观只走 `decrementImage` / `incrementImage` / `backgroundImage` / `dividerImage`。
public extension Chain where Base: UIStepper {

    /// 设置当前数值。
    /// - Parameter value: 新数值。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func value(_ value: Double) -> Chain<Base> {
        base.value = value
        return self
    }

    /// 设置最小值。
    /// 等价直接给 `UIStepper.minimumValue` 赋值。
    /// - Parameter value: 最小值。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func minimumValue(_ value: Double) -> Chain<Base> {
        base.minimumValue = value
        return self
    }

    /// 设置最大值。
    /// 等价直接给 `UIStepper.maximumValue` 赋值。
    /// - Parameter value: 最大值。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func maximumValue(_ value: Double) -> Chain<Base> {
        base.maximumValue = value
        return self
    }

    /// 设置每次点按增减的步长。
    /// - Parameter value: 步长值。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func stepValue(_ value: Double) -> Chain<Base> {
        base.stepValue = value
        return self
    }

    /// 到达边界时是否循环回绕（`true` 时超过最大值回到最小值，反之亦然）。
    /// - Parameter wraps: 是否循环。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func wraps(_ wraps: Bool) -> Chain<Base> {
        base.wraps = wraps
        return self
    }

    /// 按住按钮不放时是否自动连发（默认 `true`）。
    /// - Parameter repeats: 是否自动连发。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func autorepeat(_ repeats: Bool) -> Chain<Base> {
        base.autorepeat = repeats
        return self
    }

    /// 按住不放时是否持续发送 `valueChanged` 事件（默认 `true`）。
    /// - Parameter continuous: 是否持续派发。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isContinuous(_ continuous: Bool) -> Chain<Base> {
        base.isContinuous = continuous
        return self
    }

    /// 设置减号（−）按钮图片。
    /// 等价 `base.setDecrementImage(_:for:)`，可按不同状态分别提供图片。
    /// - Parameters:
    ///   - image: 按钮图片。
    ///   - state: 按钮状态，默认 `.normal`。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func decrementImage(_ image: UIImage?, for state: UIControl.State = .normal) -> Chain<Base> {
        base.setDecrementImage(image, for: state)
        return self
    }

    /// 设置加号（+）按钮图片。
    /// 等价 `base.setIncrementImage(_:for:)`，可按不同状态分别提供图片。
    /// - Parameters:
    ///   - image: 按钮图片。
    ///   - state: 按钮状态，默认 `.normal`。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func incrementImage(_ image: UIImage?, for state: UIControl.State = .normal) -> Chain<Base> {
        base.setIncrementImage(image, for: state)
        return self
    }

    /// 设置分段按钮背景图。
    /// 等价 `base.setBackgroundImage(_:for:)`，按状态区分（如 `.normal` / `.disabled`）。
    /// - Parameters:
    ///   - image: 背景图。
    ///   - state: 按钮状态，默认 `.normal`。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func backgroundImage(_ image: UIImage?, for state: UIControl.State = .normal) -> Chain<Base> {
        base.setBackgroundImage(image, for: state)
        return self
    }

    /// 设置两分段之间的分隔图。
    /// 需同时指定左右分段的状态（如 `.normal` / `.selected`）。
    /// - Parameters:
    ///   - image: 分隔图。
    ///   - left: 左分段状态。
    ///   - right: 右分段状态。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func dividerImage(_ image: UIImage?,
                      forLeftSegmentState left: UIControl.State,
                      rightSegmentState right: UIControl.State) -> Chain<Base> {
        base.setDividerImage(image, forLeftSegmentState: left, rightSegmentState: right)
        return self
    }
}