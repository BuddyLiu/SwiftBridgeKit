//
//  Chain+UIPickerView.swift
//  SwiftChainKit
//
//  滚轮选择器：数据源/代理。选中指示条 `showsSelectionIndicator` iOS 13 起已弃用
//  （该属性在 iOS 7+ 即无效果），库不收录弃用 API。

import UIKit

/// 滚轮选择器链式设置：数据源/代理 + 滚动与刷新动作。
///
/// 注意：选中指示条 `showsSelectionIndicator` 自 iOS 13 起已弃用
/// （该属性 iOS 7+ 实际就没有视觉效果），库不收录弃用 API。
public extension Chain where Base: UIPickerView {

    /// 设置数据源。
    /// 等价给 `UIPickerView.dataSource` 赋值，记得实现 `numberOfComponents` 与 `numberOfRowsInComponent`。
    /// - Parameter dataSource: 数据源对象。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func dataSource(_ dataSource: UIPickerViewDataSource?) -> Chain<Base> {
        base.dataSource = dataSource
        return self
    }

    /// 设置代理。
    /// 常见回调：`title(forRow:forComponent:)` 提供行文本、`didSelectRow` 监听选中。
    /// - Parameter delegate: 代理对象。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func delegate(_ delegate: UIPickerViewDelegate?) -> Chain<Base> {
        base.delegate = delegate
        return self
    }

    // MARK: - 滚动/刷新动作

    /// 滚到指定行：`selectRow(2, inComponent: 0, animated: true)`（等价 `selectRow`）。
    /// - Parameters:
    ///   - row: 目标行号。
    ///   - component: 列号。
    ///   - animated: 是否带动画滚动。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func selectRow(_ row: Int, inComponent component: Int, animated: Bool) -> Chain<Base> {
        base.selectRow(row, inComponent: component, animated: animated)
        return self
    }

    /// 全量重载：等价 `base.reloadAllComponents()`。
    /// 数据变化后调用，所有列重新取数据。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func reloadAllComponents() -> Chain<Base> {
        base.reloadAllComponents()
        return self
    }

    /// 只重载一列：等价 `base.reloadComponent(component)`。
    /// - Parameter component: 要重载的列号。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func reloadComponent(_ component: Int) -> Chain<Base> {
        base.reloadComponent(component)
        return self
    }
}