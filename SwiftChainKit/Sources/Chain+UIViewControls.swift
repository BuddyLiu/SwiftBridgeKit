//
//  Chain+UIViewControls.swift
//  SwiftChainKit
//
//  一组表单/控件类：把 target-action、可用态与各控件高频属性收进来。
//  按类拆 extension，互不越权（Chain<UISwitch> 只见得到开关的方法）。
//  文字类 property 归属：UITextField/UISearchBar 的在这里，UILabel 的在
//  Chain+UILabel.swift —— 各自的 Base 约束不同，天然不冲突。

import UIKit

// MARK: - UIControl（target-action / 可用态 / 对齐，所有控件通用）

/// 控件通用链式设置：target-action、可用态与对齐方式，所有 UIControl 子类通用。
public extension Chain where Base: UIControl {

    /// 事件挂接。
    ///
    /// 等价 `base.addTarget(target, action: action, for: events)`。
    /// - Parameters:
    ///   - target: 事件响应目标对象。
    ///   - action: 响应方法选择子。
    ///   - events: 触发事件类型（`UIControl.Event`）。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func target(_ target: Any?, action: Selector, for events: UIControl.Event) -> Chain<Base> {
        base.addTarget(target, action: action, for: events)
        return self
    }

    /// 移除目标对象上的指定事件挂接。
    ///
    /// 等价 `base.removeTarget(target, action: action, for: events)`。
    /// - Parameters:
    ///   - target: 目标对象，传 nil 表示匹配所有目标。
    ///   - action: 响应方法选择子，传 nil 表示匹配全部 action。
    ///   - events: 事件类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func removeTarget(_ target: Any?, action: Selector?, for events: UIControl.Event) -> Chain<Base> {
        base.removeTarget(target, action: action, for: events)
        return self
    }

    /// 设置控件是否可用。
    ///
    /// 等价直接给 `base.isEnabled` 赋值。
    /// - Parameter enabled: 是否可用。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isEnabled(_ enabled: Bool) -> Chain<Base> {
        base.isEnabled = enabled
        return self
    }

    /// 设置控件选中态。
    ///
    /// 等价直接给 `base.isSelected` 赋值。
    /// - Parameter selected: 是否选中。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isSelected(_ selected: Bool) -> Chain<Base> {
        base.isSelected = selected
        return self
    }

    /// 设置控件高亮态。
    ///
    /// 等价直接给 `base.isHighlighted` 赋值。
    /// - Parameter highlighted: 是否高亮。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isHighlighted(_ highlighted: Bool) -> Chain<Base> {
        base.isHighlighted = highlighted
        return self
    }

    /// 设置内容垂直对齐方式。
    ///
    /// 等价直接给 `base.contentVerticalAlignment` 赋值。
    /// - Parameter alignment: 垂直对齐方式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func contentVerticalAlignment(_ alignment: UIControl.ContentVerticalAlignment) -> Chain<Base> {
        base.contentVerticalAlignment = alignment
        return self
    }

    /// 设置内容水平对齐方式。
    ///
    /// 等价直接给 `base.contentHorizontalAlignment` 赋值。
    /// - Parameter alignment: 水平对齐方式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func contentHorizontalAlignment(_ alignment: UIControl.ContentHorizontalAlignment) -> Chain<Base> {
        base.contentHorizontalAlignment = alignment
        return self
    }
}

// MARK: - UISwitch

/// `UISwitch` 链式设置：开关状态与配色。
public extension Chain where Base: UISwitch {

    /// 设置开关的开合状态，可选带动画。
    ///
    /// 带动画时等价 `base.setOn(on, animated: true)`，否则直接给 `base.isOn` 赋值。
    /// - Parameters:
    ///   - on: 是否打开。
    ///   - animated: 是否带动画（默认 false）。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isOn(_ on: Bool, animated: Bool = false) -> Chain<Base> {
        if animated {
            base.setOn(on, animated: true)
        } else {
            base.isOn = on
        }
        return self
    }

    /// 设置打开态轨道颜色。
    ///
    /// 等价直接给 `base.onTintColor` 赋值。
    /// - Parameter color: 打开态轨道颜色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func onTintColor(_ color: UIColor?) -> Chain<Base> {
        base.onTintColor = color
        return self
    }

    /// 设置滑块颜色。
    ///
    /// 等价直接给 `base.thumbTintColor` 赋值。
    /// - Parameter color: 滑块颜色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func thumbTintColor(_ color: UIColor?) -> Chain<Base> {
        base.thumbTintColor = color
        return self
    }

    // MARK: iOS 14+ 扩充

    /// 设置开关样式偏好：`.automatic` / `.checkbox` / `.sliding`（iOS 14+）。
    ///
    /// 等价直接给 `base.preferredStyle` 赋值。
    /// - Parameter style: 开关样式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func preferredStyle(_ style: UISwitch.Style) -> Chain<Base> {
        base.preferredStyle = style
        return self
    }

    /// 设置开关旁的文字（iOS 14+）。
    ///
    /// 注意 UIKit 只在 Catalyst/Mac idiom 才真正展示它，iPhone/iPad 上设了也不回读
    /// （链上留位，语义对齐 API 存在性）。
    /// - Parameter title: 开关旁文字。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func title(_ title: String?) -> Chain<Base> {
        base.title = title
        return self
    }

    /// 设置打开态图标。
    ///
    /// 等价直接给 `base.onImage` 赋值。
    /// - Parameter image: 打开态图标。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func onImage(_ image: UIImage?) -> Chain<Base> {
        base.onImage = image
        return self
    }

    /// 设置关闭态图标。
    ///
    /// 等价直接给 `base.offImage` 赋值。
    /// - Parameter image: 关闭态图标。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func offImage(_ image: UIImage?) -> Chain<Base> {
        base.offImage = image
        return self
    }
}

// MARK: - UISegmentedControl

/// `UISegmentedControl` 链式设置：选中段、分段内容与增删。
public extension Chain where Base: UISegmentedControl {

    /// 设置当前选中分段的索引。
    ///
    /// 等价直接给 `base.selectedSegmentIndex` 赋值。
    /// - Parameter index: 选中分段索引。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func selectedSegmentIndex(_ index: Int) -> Chain<Base> {
        base.selectedSegmentIndex = index
        return self
    }

    /// 设置选中分段的高亮颜色。
    ///
    /// 等价直接给 `base.selectedSegmentTintColor` 赋值。
    /// - Parameter color: 选中分段颜色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func selectedSegmentTintColor(_ color: UIColor?) -> Chain<Base> {
        base.selectedSegmentTintColor = color
        return self
    }

    /// 设置是否为瞬时模式（选中不保持）。
    ///
    /// 等价直接给 `base.isMomentary` 赋值。
    /// - Parameter momentary: 是否瞬时模式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isMomentary(_ momentary: Bool) -> Chain<Base> {
        base.isMomentary = momentary
        return self
    }

    /// 设置分段宽度是否按内容自适应。
    ///
    /// 等价直接给 `base.apportionsSegmentWidthsByContent` 赋值。
    /// - Parameter apportions: 是否按内容分配宽度。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func apportionsSegmentWidthsByContent(_ apportions: Bool) -> Chain<Base> {
        base.apportionsSegmentWidthsByContent = apportions
        return self
    }

    /// 设置指定分段的标题。
    ///
    /// 等价 `base.setTitle(title, forSegmentAt: index)`。
    /// - Parameters:
    ///   - title: 分段标题。
    ///   - index: 分段索引。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func title(_ title: String?, forSegmentAt index: Int) -> Chain<Base> {
        base.setTitle(title, forSegmentAt: index)
        return self
    }

    /// 设置指定分段的图片。
    ///
    /// 等价 `base.setImage(image, forSegmentAt: index)`。
    /// - Parameters:
    ///   - image: 分段图片。
    ///   - index: 分段索引。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func image(_ image: UIImage?, forSegmentAt index: Int) -> Chain<Base> {
        base.setImage(image, forSegmentAt: index)
        return self
    }

    /// 设置指定分段是否可用。
    ///
    /// 等价 `base.setEnabled(enabled, forSegmentAt: index)`。
    /// - Parameters:
    ///   - enabled: 是否可用。
    ///   - index: 分段索引。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isEnabled(_ enabled: Bool, forSegmentAt index: Int) -> Chain<Base> {
        base.setEnabled(enabled, forSegmentAt: index)
        return self
    }

    /// 设置指定分段的宽度。
    ///
    /// 等价 `base.setWidth(width, forSegmentAt: index)`。
    /// - Parameters:
    ///   - width: 分段宽度。
    ///   - index: 分段索引。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func width(_ width: CGFloat, forSegmentAt index: Int) -> Chain<Base> {
        base.setWidth(width, forSegmentAt: index)
        return self
    }

    /// 设置指定分段内容的内偏移。
    ///
    /// 等价 `base.setContentOffset(offset, forSegmentAt: index)`。
    /// - Parameters:
    ///   - offset: 分段内容偏移。
    ///   - index: 分段索引。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func contentOffset(_ offset: CGSize, forSegmentAt index: Int) -> Chain<Base> {
        base.setContentOffset(offset, forSegmentAt: index)
        return self
    }

    /// 在指定索引插入一个新分段（带标题，不带动画）。
    ///
    /// 等价 `base.insertSegment(withTitle: title, at: index, animated: false)`。
    /// - Parameters:
    ///   - title: 新分段标题。
    ///   - index: 插入位置索引。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func insertSegment(withTitle title: String?, at index: Int) -> Chain<Base> {
        base.insertSegment(withTitle: title, at: index, animated: false)
        return self
    }

    /// 在指定索引插入一个新分段（带图片，不带动画）。
    ///
    /// 等价 `base.insertSegment(with: image, at: index, animated: false)`。
    /// - Parameters:
    ///   - image: 新分段图片。
    ///   - index: 插入位置索引。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func insertSegment(image: UIImage?, at index: Int) -> Chain<Base> {
        base.insertSegment(with: image, at: index, animated: false)
        return self
    }

    /// 移除指定索引的分段（不带动画）。
    ///
    /// 等价 `base.removeSegment(at: index, animated: false)`。
    /// - Parameter index: 待移除分段索引。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func removeSegment(at index: Int) -> Chain<Base> {
        base.removeSegment(at: index, animated: false)
        return self
    }

    /// 移除全部分段。
    ///
    /// 等价 `base.removeAllSegments()`，清空后需重新 insert。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func removeAllSegments() -> Chain<Base> {
        base.removeAllSegments()
        return self
    }
}

// MARK: - UISlider

/// `UISlider` 链式设置：数值、轨道与滑块外观。
public extension Chain where Base: UISlider {

    /// 设置滑块当前值（不带动画）。
    ///
    /// 等价直接给 `base.value` 赋值。
    /// - Parameter value: 当前值。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func value(_ value: Float) -> Chain<Base> {
        base.value = value
        return self
    }

    /// 设置滑块当前值，可选带动画。
    ///
    /// 等价 `base.setValue(value, animated: animated)`。
    /// - Parameters:
    ///   - value: 当前值。
    ///   - animated: 是否带动画。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func value(_ value: Float, animated: Bool) -> Chain<Base> {
        base.setValue(value, animated: animated)
        return self
    }

    /// 设置最小值。
    ///
    /// 等价直接给 `base.minimumValue` 赋值。
    /// - Parameter value: 最小值。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func minimumValue(_ value: Float) -> Chain<Base> {
        base.minimumValue = value
        return self
    }

    /// 设置最大值。
    ///
    /// 等价直接给 `base.maximumValue` 赋值。
    /// - Parameter value: 最大值。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func maximumValue(_ value: Float) -> Chain<Base> {
        base.maximumValue = value
        return self
    }

    /// 设置最小值端图标。
    ///
    /// 等价直接给 `base.minimumValueImage` 赋值。
    /// - Parameter image: 最小值端图标。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func minimumValueImage(_ image: UIImage?) -> Chain<Base> {
        base.minimumValueImage = image
        return self
    }

    /// 设置最大值端图标。
    ///
    /// 等价直接给 `base.maximumValueImage` 赋值。
    /// - Parameter image: 最大值端图标。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func maximumValueImage(_ image: UIImage?) -> Chain<Base> {
        base.maximumValueImage = image
        return self
    }

    /// 设置拖动过程中是否持续触发值改变。
    ///
    /// 等价直接给 `base.isContinuous` 赋值。
    /// - Parameter continuous: 是否持续触发。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isContinuous(_ continuous: Bool) -> Chain<Base> {
        base.isContinuous = continuous
        return self
    }

    /// 设置最小值侧（已滑过部分）的轨道颜色。
    ///
    /// 等价直接给 `base.minimumTrackTintColor` 赋值。
    /// - Parameter color: 轨道颜色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func minimumTrackTintColor(_ color: UIColor?) -> Chain<Base> {
        base.minimumTrackTintColor = color
        return self
    }

    /// 设置最大值侧（未滑过部分）的轨道颜色。
    ///
    /// 等价直接给 `base.maximumTrackTintColor` 赋值。
    /// - Parameter color: 轨道颜色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func maximumTrackTintColor(_ color: UIColor?) -> Chain<Base> {
        base.maximumTrackTintColor = color
        return self
    }

    /// 设置滑块颜色。
    ///
    /// 等价直接给 `base.thumbTintColor` 赋值。
    /// - Parameter color: 滑块颜色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func thumbTintColor(_ color: UIColor?) -> Chain<Base> {
        base.thumbTintColor = color
        return self
    }

    /// 设置指定状态下滑块的图片。
    ///
    /// 等价 `base.setThumbImage(image, for: state)`，默认配置 `.normal` 态。
    /// - Parameters:
    ///   - image: 滑块图片。
    ///   - state: 控件状态（默认 `.normal`）。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func thumbImage(_ image: UIImage?, for state: UIControl.State = .normal) -> Chain<Base> {
        base.setThumbImage(image, for: state)
        return self
    }
}

// MARK: - UITextField

/// `UITextField` 链式设置：文本内容、外观、输入面板与键盘 trait。
public extension Chain where Base: UITextField {

    /// 设置文本内容。
    ///
    /// 等价直接给 `base.text` 赋值。
    /// - Parameter text: 显示文本。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func text(_ text: String?) -> Chain<Base> {
        base.text = text
        return self
    }

    /// 设置富文本内容。
    ///
    /// 等价直接给 `base.attributedText` 赋值，优先级高于 `text`。
    /// - Parameter text: 富文本内容。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func attributedText(_ text: NSAttributedString?) -> Chain<Base> {
        base.attributedText = text
        return self
    }

    /// 设置占位文案。
    ///
    /// 等价直接给 `base.placeholder` 赋值。
    /// - Parameter placeholder: 占位文案。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func placeholder(_ placeholder: String?) -> Chain<Base> {
        base.placeholder = placeholder
        return self
    }

    /// 设置富文本占位文案。
    ///
    /// 等价直接给 `base.attributedPlaceholder` 赋值。
    /// - Parameter placeholder: 富文本占位文案。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func attributedPlaceholder(_ placeholder: NSAttributedString?) -> Chain<Base> {
        base.attributedPlaceholder = placeholder
        return self
    }

    /// 设置默认文本属性。
    ///
    /// 等价直接给 `base.defaultTextAttributes` 赋值，影响后续输入的文字。
    /// - Parameter attributes: 文本属性字典。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func defaultTextAttributes(_ attributes: [NSAttributedString.Key: Any]) -> Chain<Base> {
        base.defaultTextAttributes = attributes
        return self
    }

    /// 设置边框样式。
    ///
    /// 等价直接给 `base.borderStyle` 赋值。
    /// - Parameter style: 边框样式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func borderStyle(_ style: UITextField.BorderStyle) -> Chain<Base> {
        base.borderStyle = style
        return self
    }

    /// 设置字体。
    ///
    /// 等价直接给 `base.font` 赋值。
    /// - Parameter font: 字体。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func font(_ font: UIFont) -> Chain<Base> {
        base.font = font
        return self
    }

    /// 设置文字颜色。
    ///
    /// 等价直接给 `base.textColor` 赋值。
    /// - Parameter color: 文字颜色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func textColor(_ color: UIColor?) -> Chain<Base> {
        base.textColor = color
        return self
    }

    /// 设置文字对齐方式。
    ///
    /// 等价直接给 `base.textAlignment` 赋值。
    /// - Parameter alignment: 对齐方式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func textAlignment(_ alignment: NSTextAlignment) -> Chain<Base> {
        base.textAlignment = alignment
        return self
    }

    /// 设置开始编辑时是否清空已有内容。
    ///
    /// 等价直接给 `base.clearsOnBeginEditing` 赋值。
    /// - Parameter clears: 开始编辑时是否清空。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func clearsOnBeginEditing(_ clears: Bool) -> Chain<Base> {
        base.clearsOnBeginEditing = clears
        return self
    }

    /// 设置继续输入时是否先清空已有内容。
    ///
    /// 等价直接给 `base.clearsOnInsertion` 赋值。
    /// - Parameter clears: 继续输入时是否先清空。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func clearsOnInsertion(_ clears: Bool) -> Chain<Base> {
        base.clearsOnInsertion = clears
        return self
    }

    /// 设置文字过长时是否自动缩字号适配。
    ///
    /// 等价直接给 `base.adjustsFontSizeToFitWidth` 赋值。
    /// - Parameter adjusts: 是否自动缩字号。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func adjustsFontSizeToFitWidth(_ adjusts: Bool) -> Chain<Base> {
        base.adjustsFontSizeToFitWidth = adjusts
        return self
    }

    /// 设置自动缩字号的最小值。
    ///
    /// 等价直接给 `base.minimumFontSize` 赋值。
    /// - Parameter size: 最小字号。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func minimumFontSize(_ size: CGFloat) -> Chain<Base> {
        base.minimumFontSize = size
        return self
    }

    /// 设置清除按钮的显示时机。
    ///
    /// 等价直接给 `base.clearButtonMode` 赋值。
    /// - Parameter mode: 显示时机。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func clearButtonMode(_ mode: UITextField.ViewMode) -> Chain<Base> {
        base.clearButtonMode = mode
        return self
    }

    /// 设置左侧附加视图。
    ///
    /// 等价直接给 `base.leftView` 赋值，配合 `leftViewMode` 控制显示时机。
    /// - Parameter view: 左侧视图。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func leftView(_ view: UIView?) -> Chain<Base> {
        base.leftView = view
        return self
    }

    /// 设置左侧附加视图的显示时机。
    ///
    /// 等价直接给 `base.leftViewMode` 赋值。
    /// - Parameter mode: 显示时机。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func leftViewMode(_ mode: UITextField.ViewMode) -> Chain<Base> {
        base.leftViewMode = mode
        return self
    }

    /// 设置右侧附加视图。
    ///
    /// 等价直接给 `base.rightView` 赋值，配合 `rightViewMode` 控制显示时机。
    /// - Parameter view: 右侧视图。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func rightView(_ view: UIView?) -> Chain<Base> {
        base.rightView = view
        return self
    }

    /// 设置右侧附加视图的显示时机。
    ///
    /// 等价直接给 `base.rightViewMode` 赋值。
    /// - Parameter mode: 显示时机。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func rightViewMode(_ mode: UITextField.ViewMode) -> Chain<Base> {
        base.rightViewMode = mode
        return self
    }

    /// 设置背景图。
    ///
    /// 等价直接给 `base.background` 赋值。
    /// - Parameter image: 背景图。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func background(_ image: UIImage?) -> Chain<Base> {
        base.background = image
        return self
    }

    /// 设置禁用态背景图。
    ///
    /// 等价直接给 `base.disabledBackground` 赋值。
    /// - Parameter image: 禁用态背景图。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func disabledBackground(_ image: UIImage?) -> Chain<Base> {
        base.disabledBackground = image
        return self
    }

    /// 设置是否允许编辑富文本属性。
    ///
    /// 等价直接给 `base.allowsEditingTextAttributes` 赋值。
    /// - Parameter allows: 是否允许编辑富文本属性。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func allowsEditingTextAttributes(_ allows: Bool) -> Chain<Base> {
        base.allowsEditingTextAttributes = allows
        return self
    }

    /// 设置输入中的富文本属性。
    ///
    /// 等价直接给 `base.typingAttributes` 赋值。
    /// - Parameter attributes: 输入属性字典。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func typingAttributes(_ attributes: [NSAttributedString.Key: Any]?) -> Chain<Base> {
        base.typingAttributes = attributes
        return self
    }

    // MARK: - 自定义输入面板（替代键盘）

    /// 自定义输入面板替代系统键盘。
    ///
    /// 设为非 nil 后聚焦不弹系统键盘（等同 `base.inputView`）。
    /// - Parameter view: 自定义输入面板。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func inputView(_ view: UIView?) -> Chain<Base> {
        base.inputView = view
        return self
    }

    /// 设置键盘上方的工具条。
    ///
    /// 设日期/选择器时常用的「确定」条放这里（等同 `base.inputAccessoryView`）。
    /// - Parameter view: 工具条视图。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func inputAccessoryView(_ view: UIView?) -> Chain<Base> {
        base.inputAccessoryView = view
        return self
    }

    // MARK: - 键盘（UITextInputTraits）

    /// 设置键盘右下角回车键样式。
    ///
    /// 等价直接给 `base.returnKeyType` 赋值，如 `.done` / `.search`。
    /// - Parameter type: 回车键样式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func returnKeyType(_ type: UIReturnKeyType) -> Chain<Base> {
        base.returnKeyType = type
        return self
    }

    /// 设置键盘类型。
    ///
    /// 等价直接给 `base.keyboardType` 赋值，如 `.numberPad` / `.emailAddress`。
    /// - Parameter type: 键盘类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func keyboardType(_ type: UIKeyboardType) -> Chain<Base> {
        base.keyboardType = type
        return self
    }

    /// 设置键盘外观。
    ///
    /// 等价直接给 `base.keyboardAppearance` 赋值，控制明暗主题。
    /// - Parameter appearance: 键盘外观。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func keyboardAppearance(_ appearance: UIKeyboardAppearance) -> Chain<Base> {
        base.keyboardAppearance = appearance
        return self
    }

    /// 设置自动首字母大写。
    ///
    /// 等价直接给 `base.autocapitalizationType` 赋值。
    /// - Parameter type: 自动大写类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func autocapitalizationType(_ type: UITextAutocapitalizationType) -> Chain<Base> {
        base.autocapitalizationType = type
        return self
    }

    /// 设置自动纠错。
    ///
    /// 等价直接给 `base.autocorrectionType` 赋值，`.no` 可关闭纠错。
    /// - Parameter type: 自动纠错类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func autocorrectionType(_ type: UITextAutocorrectionType) -> Chain<Base> {
        base.autocorrectionType = type
        return self
    }

    /// 设置拼写检查。
    ///
    /// 等价直接给 `base.spellCheckingType` 赋值。
    /// - Parameter type: 拼写检查类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func spellCheckingType(_ type: UITextSpellCheckingType) -> Chain<Base> {
        base.spellCheckingType = type
        return self
    }

    /// 设置智能引号。
    ///
    /// 等价直接给 `base.smartQuotesType` 赋值。
    /// - Parameter type: 智能引号类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func smartQuotesType(_ type: UITextSmartQuotesType) -> Chain<Base> {
        base.smartQuotesType = type
        return self
    }

    /// 设置智能破折号。
    ///
    /// 等价直接给 `base.smartDashesType` 赋值。
    /// - Parameter type: 智能破折号类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func smartDashesType(_ type: UITextSmartDashesType) -> Chain<Base> {
        base.smartDashesType = type
        return self
    }

    /// 设置智能插入/删除。
    ///
    /// 等价直接给 `base.smartInsertDeleteType` 赋值。
    /// - Parameter type: 智能插入/删除类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func smartInsertDeleteType(_ type: UITextSmartInsertDeleteType) -> Chain<Base> {
        base.smartInsertDeleteType = type
        return self
    }

    /// 设置无内容时是否禁用回车键。
    ///
    /// 等价直接给 `base.enablesReturnKeyAutomatically` 赋值。
    /// - Parameter enables: 是否自动禁用回车键。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func enablesReturnKeyAutomatically(_ enables: Bool) -> Chain<Base> {
        base.enablesReturnKeyAutomatically = enables
        return self
    }

    /// 设置是否为安全输入（密码）。
    ///
    /// 等价直接给 `base.isSecureTextEntry` 赋值。
    /// - Parameter secure: 是否安全输入。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isSecureTextEntry(_ secure: Bool) -> Chain<Base> {
        base.isSecureTextEntry = secure
        return self
    }

    /// 设置文本输入代理。
    ///
    /// 代理对象须遵循 `UITextFieldDelegate`，用于拦截编辑事件。注意代理是弱引用。
    /// - Parameter delegate: 文本输入代理。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func delegate(_ delegate: UITextFieldDelegate?) -> Chain<Base> {
        base.delegate = delegate
        return self
    }
}

// MARK: - UISearchBar

/// `UISearchBar` 链式设置：文案、外观、键盘 trait 与 Scope 栏。
public extension Chain where Base: UISearchBar {

    /// 设置搜索框文本。
    ///
    /// 等价直接给 `base.text` 赋值。
    /// - Parameter text: 搜索文本。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func text(_ text: String?) -> Chain<Base> {
        base.text = text
        return self
    }

    /// 设置搜索框上方的提示文案。
    ///
    /// 等价直接给 `base.prompt` 赋值。
    /// - Parameter prompt: 提示文案。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func prompt(_ prompt: String?) -> Chain<Base> {
        base.prompt = prompt
        return self
    }

    /// 设置占位文案。
    ///
    /// 等价直接给 `base.placeholder` 赋值。
    /// - Parameter placeholder: 占位文案。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func placeholder(_ placeholder: String?) -> Chain<Base> {
        base.placeholder = placeholder
        return self
    }

    /// 设置搜索框样式。
    ///
    /// 等价直接给 `base.searchBarStyle` 赋值，影响外观与位置。
    /// - Parameter style: 搜索框样式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func searchBarStyle(_ style: UISearchBar.Style) -> Chain<Base> {
        base.searchBarStyle = style
        return self
    }

    /// 设置搜索栏背景色。
    ///
    /// 等价直接给 `base.barTintColor` 赋值。
    /// - Parameter color: 背景色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func barTintColor(_ color: UIColor?) -> Chain<Base> {
        base.barTintColor = color
        return self
    }

    /// 设置是否半透明。
    ///
    /// 等价直接给 `base.isTranslucent` 赋值。
    /// - Parameter translucent: 是否半透明。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isTranslucent(_ translucent: Bool) -> Chain<Base> {
        base.isTranslucent = translucent
        return self
    }

    /// 设置是否显示取消按钮，可选带动画。
    ///
    /// 等价 `base.setShowsCancelButton(shows, animated: animated)`。
    /// - Parameters:
    ///   - shows: 是否显示取消按钮。
    ///   - animated: 是否带动画（默认 false）。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func showsCancelButton(_ shows: Bool, animated: Bool = false) -> Chain<Base> {
        base.setShowsCancelButton(shows, animated: animated)
        return self
    }

    /// 设置是否显示书签按钮。
    ///
    /// 等价直接给 `base.showsBookmarkButton` 赋值。
    /// - Parameter shows: 是否显示。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func showsBookmarkButton(_ shows: Bool) -> Chain<Base> {
        base.showsBookmarkButton = shows
        return self
    }

    /// 设置是否显示搜索结果切换按钮。
    ///
    /// 等价直接给 `base.showsSearchResultsButton` 赋值。
    /// - Parameter shows: 是否显示。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func showsSearchResultsButton(_ shows: Bool) -> Chain<Base> {
        base.showsSearchResultsButton = shows
        return self
    }

    /// 设置搜索结果按钮是否处于选中态。
    ///
    /// 等价直接给 `base.isSearchResultsButtonSelected` 赋值。
    /// - Parameter selected: 是否选中。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isSearchResultsButtonSelected(_ selected: Bool) -> Chain<Base> {
        base.isSearchResultsButtonSelected = selected
        return self
    }

    /// 设置搜索框背景的位置偏移。
    ///
    /// 等价直接给 `base.searchFieldBackgroundPositionAdjustment` 赋值。
    /// - Parameter adjustment: 位置偏移。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func searchFieldBackgroundPositionAdjustment(_ adjustment: UIOffset) -> Chain<Base> {
        base.searchFieldBackgroundPositionAdjustment = adjustment
        return self
    }

    /// 设置搜索文本的位置偏移。
    ///
    /// 等价直接给 `base.searchTextPositionAdjustment` 赋值。
    /// - Parameter adjustment: 位置偏移。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func searchTextPositionAdjustment(_ adjustment: UIOffset) -> Chain<Base> {
        base.searchTextPositionAdjustment = adjustment
        return self
    }

    // MARK: - 键盘（UITextInputTraits）

    /// 设置键盘右下角回车键样式。
    ///
    /// 等价直接给 `base.returnKeyType` 赋值，如 `.done` / `.search`。
    /// - Parameter type: 回车键样式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func returnKeyType(_ type: UIReturnKeyType) -> Chain<Base> {
        base.returnKeyType = type
        return self
    }

    /// 设置键盘类型。
    ///
    /// 等价直接给 `base.keyboardType` 赋值，如 `.numberPad` / `.emailAddress`。
    /// - Parameter type: 键盘类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func keyboardType(_ type: UIKeyboardType) -> Chain<Base> {
        base.keyboardType = type
        return self
    }

    /// 设置自动首字母大写。
    ///
    /// 等价直接给 `base.autocapitalizationType` 赋值。
    /// - Parameter type: 自动大写类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func autocapitalizationType(_ type: UITextAutocapitalizationType) -> Chain<Base> {
        base.autocapitalizationType = type
        return self
    }

    /// 设置自动纠错。
    ///
    /// 等价直接给 `base.autocorrectionType` 赋值，`.no` 可关闭纠错。
    /// - Parameter type: 自动纠错类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func autocorrectionType(_ type: UITextAutocorrectionType) -> Chain<Base> {
        base.autocorrectionType = type
        return self
    }

    /// 设置拼写检查。
    ///
    /// 等价直接给 `base.spellCheckingType` 赋值。
    /// - Parameter type: 拼写检查类型。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func spellCheckingType(_ type: UITextSpellCheckingType) -> Chain<Base> {
        base.spellCheckingType = type
        return self
    }

    /// 设置键盘外观。
    ///
    /// 等价直接给 `base.keyboardAppearance` 赋值，控制明暗主题。
    /// - Parameter appearance: 键盘外观。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func keyboardAppearance(_ appearance: UIKeyboardAppearance) -> Chain<Base> {
        base.keyboardAppearance = appearance
        return self
    }

    /// 设置无内容时是否禁用回车键。
    ///
    /// 等价直接给 `base.enablesReturnKeyAutomatically` 赋值。
    /// - Parameter enables: 是否自动禁用回车键。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func enablesReturnKeyAutomatically(_ enables: Bool) -> Chain<Base> {
        base.enablesReturnKeyAutomatically = enables
        return self
    }

    // MARK: - Scope 栏

    /// 设置 Scope 栏按钮标题数组。
    ///
    /// 等价直接给 `base.scopeButtonTitles` 赋值，传 nil 隐藏 Scope 栏。
    /// - Parameter titles: 各按钮标题。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func scopeButtonTitles(_ titles: [String]?) -> Chain<Base> {
        base.scopeButtonTitles = titles
        return self
    }

    /// 设置当前选中的 Scope 按钮索引。
    ///
    /// 等价直接给 `base.selectedScopeButtonIndex` 赋值。
    /// - Parameter index: 选中索引。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func selectedScopeButtonIndex(_ index: Int) -> Chain<Base> {
        base.selectedScopeButtonIndex = index
        return self
    }

    /// 设置是否显示 Scope 栏。
    ///
    /// 等价直接给 `base.showsScopeBar` 赋值。
    /// - Parameter shows: 是否显示。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func showsScopeBar(_ shows: Bool) -> Chain<Base> {
        base.showsScopeBar = shows
        return self
    }

    /// 设置 Scope 栏背景图。
    ///
    /// 等价直接给 `base.scopeBarBackgroundImage` 赋值。
    /// - Parameter image: 背景图。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func scopeBarBackgroundImage(_ image: UIImage?) -> Chain<Base> {
        base.scopeBarBackgroundImage = image
        return self
    }

    /// 设置搜索栏背景图。
    ///
    /// 参数与你预期一致的话，一般直接 `.backgroundImage(img)` 即可。
    /// 注意 UISearchBar 只有 `setBackgroundImage(_:for:barMetrics:)` 三参版（UIBarPosition 在前）。
    /// - Parameters:
    ///   - image: 背景图。
    ///   - position: 栏位置（默认 `.any`）。
    ///   - barMetrics: 栏度量（默认 `.default`）。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func backgroundImage(_ image: UIImage?,
                         for position: UIBarPosition = .any,
                         barMetrics: UIBarMetrics = .default) -> Chain<Base> {
        base.setBackgroundImage(image, for: position, barMetrics: barMetrics)
        return self
    }

    /// 设置 Scope 按钮在指定状态下的背景图。
    ///
    /// 等价 `base.setScopeBarButtonBackgroundImage(image, for: state)`。
    /// - Parameters:
    ///   - image: 背景图。
    ///   - state: 按钮状态。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func scopeBarButtonBackgroundImage(_ image: UIImage?, for state: UIControl.State) -> Chain<Base> {
        base.setScopeBarButtonBackgroundImage(image, for: state)
        return self
    }

    /// 设置搜索栏代理。
    ///
    /// 代理对象须遵循 `UISearchBarDelegate`。注意代理是弱引用。
    /// - Parameter delegate: 搜索栏代理。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func delegate(_ delegate: UISearchBarDelegate?) -> Chain<Base> {
        base.delegate = delegate
        return self
    }
}