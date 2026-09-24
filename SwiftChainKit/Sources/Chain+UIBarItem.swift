//
//  Chain+UIBarItem.swift
//  SwiftChainKit
//
//  导航/标签栏上的条目类：UIBarButtonItem、UITabBarItem、UINavigationItem。
//  它们不是 UIView，进链只能走静态工厂（`UIBarButtonItem.chain(...)`）。
//  UIBarItem 共有的 title/tag/isEnabled/accessibility 收在共享基座扩展里。

import UIKit

// MARK: - UIBarItem 共享基座（UIBarButtonItem / UITabBarItem 都继承它）

/// `UIBarItem` 共享基座扩展：`UIBarButtonItem` / `UITabBarItem` 都继承它，
/// 放着两栏共有的 title / tag / isEnabled / accessibility 配置。
public extension Chain where Base: UIBarItem {

    /// 设置条目标题。
    /// 等价直接给 `base.title` 赋值。
    /// - Parameter title: 新标题。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func title(_ title: String?) -> Chain<Base> {
        base.title = title
        return self
    }

    /// 设置条目是否可用（等价 `base.isEnabled = enabled`）。
    /// - Parameter enabled: 是否可用。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isEnabled(_ enabled: Bool) -> Chain<Base> {
        base.isEnabled = enabled
        return self
    }

    /// 设置条目标签 tag（便于批量查找）。
    /// - Parameter tag: 标签值。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func tag(_ tag: Int) -> Chain<Base> {
        base.tag = tag
        return self
    }

    /// 设置条目无障碍标签。
    /// 等价 `base.accessibilityLabel = label`。
    /// - Parameter label: 无障碍标签文案。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func accessibilityLabel(_ label: String?) -> Chain<Base> {
        base.accessibilityLabel = label
        return self
    }
}

// MARK: - UIBarButtonItem

/// `UIBarButtonItem` 的链式工厂集合。
///
/// `UIBarButtonItem` 不是 UIView，没有 `.chain()`，静态工厂是进链的唯一入口。
public extension UIBarButtonItem {

    /// 用标题文本创建 `UIBarButtonItem` 并进入链。
    ///
    /// 等价 `UIBarButtonItem(title:style:target:action:)`。
    /// - Parameters:
    ///   - title: 按钮标题文本。
    ///   - style: 按钮样式（`.plain` / `.done`），默认 `.plain`。
    ///   - target: 点击事件目标对象。
    ///   - action: 点击事件回调选择器。
    /// - Returns: 返回可链式设置的 `Chain<UIBarButtonItem>`。
    @MainActor
    static func chain(title: String?,
                      style: UIBarButtonItem.Style = .plain,
                      target: Any? = nil,
                      action: Selector? = nil) -> Chain<UIBarButtonItem> {
        Chain(UIBarButtonItem(title: title, style: style, target: target, action: action))
    }

    /// 用系统内置图标创建 `UIBarButtonItem` 并进入链。
    ///
    /// 等价 `UIBarButtonItem(barButtonSystemItem:target:action:)`。
    /// - Parameter systemItem: 系统图标风格（`UIBarButtonItem.SystemItem`）。
    /// - Returns: 返回可链式设置的 `Chain<UIBarButtonItem>`。
    @MainActor
    static func chain(systemItem: UIBarButtonItem.SystemItem) -> Chain<UIBarButtonItem> {
        Chain(UIBarButtonItem(barButtonSystemItem: systemItem, target: nil, action: nil))
    }
}

/// `UIBarButtonItem` 独有属性（图标、样式、点击回调等）。
public extension Chain where Base: UIBarButtonItem {

    /// 设置按钮图标（等价 `base.image = image`）。
    /// - Parameter image: 图标。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func image(_ image: UIImage?) -> Chain<Base> {
        base.image = image
        return self
    }

    /// 设置 iPhone 横屏时使用的按钮图标。
    /// 等价 `base.landscapeImagePhone = image`。
    /// - Parameter image: 横屏图标。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func landscapeImagePhone(_ image: UIImage?) -> Chain<Base> {
        base.landscapeImagePhone = image
        return self
    }

    /// 设置图标内边距（等价 `base.imageInsets = insets`）。
    /// - Parameter insets: 内边距。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func imageInsets(_ insets: UIEdgeInsets) -> Chain<Base> {
        base.imageInsets = insets
        return self
    }

    /// 设置 iPhone 横屏时的图标边距。
    /// 等价 `base.landscapeImagePhoneInsets = insets`。
    /// - Parameter insets: 内边距。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func landscapeImagePhoneInsets(_ insets: UIEdgeInsets) -> Chain<Base> {
        base.landscapeImagePhoneInsets = insets
        return self
    }

    /// 设置图标与文字的着色（等价 `base.tintColor = color`）。
    /// - Parameter color: 着色颜色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func tintColor(_ color: UIColor?) -> Chain<Base> {
        base.tintColor = color
        return self
    }

    /// 设置按钮样式（`.plain` / `.done`）。
    /// 等价 `base.style = style`。
    /// - Parameter style: 按钮样式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func style(_ style: UIBarButtonItem.Style) -> Chain<Base> {
        base.style = style
        return self
    }

    /// 设置按钮固定宽度（等价 `base.width = width`）。
    /// - Parameter width: 宽度。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func width(_ width: CGFloat) -> Chain<Base> {
        base.width = width
        return self
    }

    /// 预留的候选标题集合（帮助系统在标题切换时预估所需宽度）。
    /// 等价 `base.possibleTitles = titles`。
    /// - Parameter titles: 候选标题集合。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func possibleTitles(_ titles: Set<String>?) -> Chain<Base> {
        base.possibleTitles = titles
        return self
    }

    /// 用自定义视图替换按钮内容（等价 `base.customView = view`）。
    /// - Parameter view: 自定义视图。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func customView(_ view: UIView?) -> Chain<Base> {
        base.customView = view
        return self
    }

    /// 设置点击事件目标对象。
    ///
    /// - Note: `UIBarButtonItem.target` 是 weak 弱引用，参数限定为类类型 `AnyObject?`；
    ///   目标对象只被弱引用，须在按钮存活期间自行保证其不被释放，否则回调不会触发。
    /// - Parameter target: 点击事件目标对象。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func target(_ target: AnyObject?) -> Chain<Base> {
        base.target = target
        return self
    }

    /// 设置点击事件回调选择器（等价 `base.action = action`）。
    /// - Parameter action: 回调选择器。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func action(_ action: Selector) -> Chain<Base> {
        base.action = action
        return self
    }
}

// MARK: - UITabBarItem

/// `UITabBarItem` 的链式工厂集合。
///
/// `UITabBarItem` 不是 UIView，没有 `.chain()`，静态工厂是进链的唯一入口。
public extension UITabBarItem {

    /// 用标题与图标创建 `UITabBarItem` 并进入链。
    ///
    /// 等价 `UITabBarItem(title:image:tag:)`。
    /// - Parameters:
    ///   - title: 标签项标题。
    ///   - image: 常规状态图标。
    ///   - tag: 标签值，默认 0。
    /// - Returns: 返回可链式设置的 `Chain<UITabBarItem>`。
    @MainActor
    static func chain(title: String?, image: UIImage?, tag: Int = 0) -> Chain<UITabBarItem> {
        Chain(UITabBarItem(title: title, image: image, tag: tag))
    }

    /// 用系统内置图标创建 `UITabBarItem` 并进入链。
    ///
    /// 等价 `UITabBarItem(tabBarSystemItem:tag:)`。
    /// - Parameters:
    ///   - systemItem: 系统图标风格（`UITabBarItem.SystemItem`）。
    ///   - tag: 标签值，默认 0。
    /// - Returns: 返回可链式设置的 `Chain<UITabBarItem>`。
    @MainActor
    static func chain(systemItem: UITabBarItem.SystemItem, tag: Int = 0) -> Chain<UITabBarItem> {
        Chain(UITabBarItem(tabBarSystemItem: systemItem, tag: tag))
    }
}

/// `UITabBarItem` 独有属性（选中态、角标等）。
public extension Chain where Base: UITabBarItem {

    /// 设置常规状态图标（等价 `base.image = image`）。
    /// - Parameter image: 图标。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func image(_ image: UIImage?) -> Chain<Base> {
        base.image = image
        return self
    }

    /// 设置选中状态图标（等价 `base.selectedImage = image`）。
    /// - Parameter image: 选中图标。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func selectedImage(_ image: UIImage?) -> Chain<Base> {
        base.selectedImage = image
        return self
    }

    /// 设置角标文字（传 `nil` 清除角标）。
    /// 等价 `base.badgeValue = value`。
    /// - Parameter value: 角标文字。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func badgeValue(_ value: String?) -> Chain<Base> {
        base.badgeValue = value
        return self
    }

    /// 设置角标背景色（iOS 10+）。
    /// 等价 `base.badgeColor = color`。
    /// - Parameter color: 角标背景色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func badgeColor(_ color: UIColor?) -> Chain<Base> {
        base.badgeColor = color
        return self
    }

    /// 调整标题相对图标的偏移（等价 `base.titlePositionAdjustment = adjustment`）。
    /// - Parameter adjustment: 偏移量。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func titlePositionAdjustment(_ adjustment: UIOffset) -> Chain<Base> {
        base.titlePositionAdjustment = adjustment
        return self
    }

    /// 设置角标文字样式。
    ///
    /// 例：`badgeTextAttributes([.foregroundColor: UIColor.white], for: .normal)`。
    /// - Parameters:
    ///   - attributes: 文字属性字典。
    ///   - state: 控件状态。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func badgeTextAttributes(_ attributes: [NSAttributedString.Key: Any]?, for state: UIControl.State) -> Chain<Base> {
        base.setBadgeTextAttributes(attributes, for: state)
        return self
    }
}

// MARK: - UINavigationItem

/// `UINavigationItem` 的链式工厂。
///
/// `UINavigationItem` 不是 UIView，没有 `.chain()`，静态工厂是进链的唯一入口。
public extension UINavigationItem {

    /// 用标题创建 `UINavigationItem` 并进入链。
    /// - Parameter title: 导航项标题。
    /// - Returns: 返回可链式设置的 `Chain<UINavigationItem>`。
    @MainActor
    static func chain(title: String) -> Chain<UINavigationItem> {
        Chain(UINavigationItem(title: title))
    }
}

/// `UINavigationItem` 的配置（标题、左右栏按钮、搜索控制器等）。
public extension Chain where Base: UINavigationItem {

    /// 设置导航项标题。
    ///
    /// 等价直接给 `UINavigationItem.title` 赋值。
    /// - Parameter title: 新标题。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func title(_ title: String?) -> Chain<Base> {
        base.title = title
        return self
    }

    /// 用自定义视图替换标题区域。
    /// 等价 `base.titleView = view`。
    /// - Parameter view: 自定义标题视图。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func titleView(_ view: UIView?) -> Chain<Base> {
        base.titleView = view
        return self
    }

    /// 设置标题下方的提示文字（等价 `base.prompt = prompt`）。
    /// - Parameter prompt: 提示文字。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func prompt(_ prompt: String?) -> Chain<Base> {
        base.prompt = prompt
        return self
    }

    /// 是否隐藏返回按钮（等价 `base.hidesBackButton = hides`）。
    /// - Parameter hides: 是否隐藏。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func hidesBackButton(_ hides: Bool) -> Chain<Base> {
        base.hidesBackButton = hides
        return self
    }

    /// 设置左侧栏按钮（等价 `base.leftBarButtonItem = item`）。
    /// - Parameter item: 左侧栏按钮。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func leftBarButtonItem(_ item: UIBarButtonItem?) -> Chain<Base> {
        base.leftBarButtonItem = item
        return self
    }

    /// 设置右侧栏按钮（等价 `base.rightBarButtonItem = item`）。
    /// - Parameter item: 右侧栏按钮。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func rightBarButtonItem(_ item: UIBarButtonItem?) -> Chain<Base> {
        base.rightBarButtonItem = item
        return self
    }

    /// 设置左侧栏按钮组（等价 `base.leftBarButtonItems = items`）。
    /// - Parameter items: 按钮数组。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func leftBarButtonItems(_ items: [UIBarButtonItem]?) -> Chain<Base> {
        base.leftBarButtonItems = items
        return self
    }

    /// 设置右侧栏按钮组（等价 `base.rightBarButtonItems = items`）。
    /// - Parameter items: 按钮数组。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func rightBarButtonItems(_ items: [UIBarButtonItem]?) -> Chain<Base> {
        base.rightBarButtonItems = items
        return self
    }

    /// 设置返回按钮（决定上一级的返回文案，等价 `base.backBarButtonItem = item`）。
    /// - Parameter item: 返回按钮。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func backBarButtonItem(_ item: UIBarButtonItem?) -> Chain<Base> {
        base.backBarButtonItem = item
        return self
    }

    /// 设置大标题展示模式（iOS 11+）。
    /// - Parameter mode: `.automatic` / `.always` / `.never`。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func largeTitleDisplayMode(_ mode: UINavigationItem.LargeTitleDisplayMode) -> Chain<Base> {
        base.largeTitleDisplayMode = mode
        return self
    }

    /// 关联搜索控制器（iOS 11+ 起）。
    /// 等价 `base.searchController = controller`。
    /// - Parameter controller: 搜索控制器。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func searchController(_ controller: UISearchController?) -> Chain<Base> {
        base.searchController = controller
        return self
    }

    /// 滚动时是否隐藏搜索条（iOS 11+ 起）。
    /// 等价 `base.hidesSearchBarWhenScrolling = hides`。
    /// - Parameter hides: 是否隐藏。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func hidesSearchBarWhenScrolling(_ hides: Bool) -> Chain<Base> {
        base.hidesSearchBarWhenScrolling = hides
        return self
    }
}