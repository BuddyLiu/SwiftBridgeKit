//
//  Chain+UIBars.swift
//  SwiftChainKit
//
//  三根系统栏：导航栏 / 标签栏 / 工具条。公共配色项各写各的（Base 不同天然不冲突），
//  外观组（appearance，iOS 13/15 起的现代路径）按类给全。

import UIKit

// MARK: - UINavigationBar

/// 导航栏 `UINavigationBar` 的链式配置。
public extension Chain where Base: UINavigationBar {

    /// 设置栏的整体风格（`.default` / `.black`）。
    /// 等价 `base.barStyle = style`。
    /// - Parameter style: 栏风格。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func barStyle(_ style: UIBarStyle) -> Chain<Base> {
        base.barStyle = style
        return self
    }

    /// 设置栏是否半透明（等价 `base.isTranslucent = translucent`）。
    /// - Parameter translucent: 是否半透明。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isTranslucent(_ translucent: Bool) -> Chain<Base> {
        base.isTranslucent = translucent
        return self
    }

    /// 设置栏的背景色调（iOS 13+ 起推荐改用外观组 `standardAppearance`）。
    /// 等价 `base.barTintColor = color`。
    /// - Parameter color: 背景色调。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func barTintColor(_ color: UIColor?) -> Chain<Base> {
        base.barTintColor = color
        return self
    }

    /// 设置标题文字样式属性（字体、颜色等）。
    /// 等价 `base.titleTextAttributes = attributes`。
    /// - Parameter attributes: 文字属性字典。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func titleTextAttributes(_ attributes: [NSAttributedString.Key: Any]?) -> Chain<Base> {
        base.titleTextAttributes = attributes
        return self
    }

    /// 设置大标题文字样式属性（iOS 11+ 起）。
    /// 等价 `base.largeTitleTextAttributes = attributes`。
    /// - Parameter attributes: 文字属性字典。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func largeTitleTextAttributes(_ attributes: [NSAttributedString.Key: Any]?) -> Chain<Base> {
        base.largeTitleTextAttributes = attributes
        return self
    }

    /// 是否优先使用大标题（iOS 11+ 起）。
    /// 等价 `base.prefersLargeTitles = prefers`。
    /// - Parameter prefers: 是否优先大标题。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func prefersLargeTitles(_ prefers: Bool) -> Chain<Base> {
        base.prefersLargeTitles = prefers
        return self
    }

    /// 设置栏底部的阴影线图片（等价 `base.shadowImage = image`）。
    /// - Parameter image: 阴影线图片。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func shadowImage(_ image: UIImage?) -> Chain<Base> {
        base.shadowImage = image
        return self
    }

    /// 设置背景图片。
    ///
    /// 例：`backgroundImage(UIImage(), for: .compact)`。
    /// - Parameters:
    ///   - image: 背景图片。
    ///   - barMetrics: 栏度量模式，默认 `.default`。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func backgroundImage(_ image: UIImage?, for barMetrics: UIBarMetrics = .default) -> Chain<Base> {
        base.setBackgroundImage(image, for: barMetrics)
        return self
    }

    /// 批量设置导航项。
    /// 等价 `base.setItems(items, animated:)`。
    /// - Parameters:
    ///   - items: 导航项数组。
    ///   - animated: 是否带动画。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func items(_ items: [UINavigationItem]?, animated: Bool) -> Chain<Base> {
        base.setItems(items, animated: animated)
        return self
    }

    /// 设置导航栏代理（等价 `base.delegate = delegate`）。
    /// - Parameter delegate: 导航栏代理。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func delegate(_ delegate: UINavigationBarDelegate?) -> Chain<Base> {
        base.delegate = delegate
        return self
    }

    // MARK: 外观组（iOS 13+）

    /// 设置标准外观（iOS 13+）。
    ///
    /// 外观组走现代路径：用 `UINavigationBarAppearance` 一次性配置背景、文字样式，
    /// 比逐个设置 barTintColor / titleTextAttributes 更接近系统推荐做法。
    /// - Parameter appearance: 标准外观。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func standardAppearance(_ appearance: UINavigationBarAppearance) -> Chain<Base> {
        base.standardAppearance = appearance
        return self
    }

    /// 设置紧凑栏（横屏小尺寸）外观（iOS 13+）。
    /// 等价 `base.compactAppearance = appearance`。
    /// - Parameter appearance: 紧凑外观。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func compactAppearance(_ appearance: UINavigationBarAppearance?) -> Chain<Base> {
        base.compactAppearance = appearance
        return self
    }

    /// 设置滚动到边缘时的外观（iOS 13+）。
    /// 等价 `base.scrollEdgeAppearance = appearance`。
    /// - Parameter appearance: 滚动边缘外观。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func scrollEdgeAppearance(_ appearance: UINavigationBarAppearance?) -> Chain<Base> {
        base.scrollEdgeAppearance = appearance
        return self
    }
}

// MARK: - UITabBar

/// 标签栏 `UITabBar` 的链式配置。
public extension Chain where Base: UITabBar {

    /// 设置栏的整体风格（`.default` / `.black`）。
    /// 等价 `base.barStyle = style`。
    /// - Parameter style: 栏风格。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func barStyle(_ style: UIBarStyle) -> Chain<Base> {
        base.barStyle = style
        return self
    }

    /// 设置栏是否半透明（等价 `base.isTranslucent = translucent`）。
    /// - Parameter translucent: 是否半透明。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isTranslucent(_ translucent: Bool) -> Chain<Base> {
        base.isTranslucent = translucent
        return self
    }

    /// 设置栏的背景色调（iOS 15+ 起推荐改用外观组 `standardAppearance`）。
    /// 等价 `base.barTintColor = color`。
    /// - Parameter color: 背景色调。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func barTintColor(_ color: UIColor?) -> Chain<Base> {
        base.barTintColor = color
        return self
    }

    /// 设置未选中项图标与文字的色调。
    /// 等价 `base.unselectedItemTintColor = color`。
    /// - Parameter color: 未选中项色调。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func unselectedItemTintColor(_ color: UIColor?) -> Chain<Base> {
        base.unselectedItemTintColor = color
        return self
    }

    /// 设置标签栏项数组（等价 `base.items = items`）。
    /// - Parameter items: 标签项数组。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func items(_ items: [UITabBarItem]?) -> Chain<Base> {
        base.items = items
        return self
    }

    /// 设置选中的标签项（等价 `base.selectedItem = item`）。
    /// - Parameter item: 选中的标签项。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func selectedItem(_ item: UITabBarItem?) -> Chain<Base> {
        base.selectedItem = item
        return self
    }

    /// 设置背景图片（等价 `base.backgroundImage = image`）。
    /// - Parameter image: 背景图片。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func backgroundImage(_ image: UIImage?) -> Chain<Base> {
        base.backgroundImage = image
        return self
    }

    /// 设置顶部阴影线图片（等价 `base.shadowImage = image`）。
    /// - Parameter image: 阴影线图片。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func shadowImage(_ image: UIImage?) -> Chain<Base> {
        base.shadowImage = image
        return self
    }

    /// 设置项的分布策略：`.automatic` / `.fill` / `.centered`。
    /// 等价 `base.itemPositioning = positioning`。
    /// - Parameter positioning: 分布策略。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func itemPositioning(_ positioning: UITabBar.ItemPositioning) -> Chain<Base> {
        base.itemPositioning = positioning
        return self
    }

    /// 设置项固定宽度（`.automatic` 分布下忽略）。
    /// 等价 `base.itemWidth = width`。
    /// - Parameter width: 项宽度。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func itemWidth(_ width: CGFloat) -> Chain<Base> {
        base.itemWidth = width
        return self
    }

    /// 设置项间距（`.automatic` 分布下忽略）。
    /// 等价 `base.itemSpacing = spacing`。
    /// - Parameter spacing: 项间距。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func itemSpacing(_ spacing: CGFloat) -> Chain<Base> {
        base.itemSpacing = spacing
        return self
    }

    /// 设置标签栏代理（等价 `base.delegate = delegate`）。
    /// - Parameter delegate: 标签栏代理。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func delegate(_ delegate: UITabBarDelegate?) -> Chain<Base> {
        base.delegate = delegate
        return self
    }

    // MARK: 外观组（iOS 15+）

    /// 设置标准外观（iOS 15+）。
    ///
    /// 外观组走现代路径：用 `UITabBarAppearance` 一次性配置背景、文字等，
    /// 替代逐个设置 barTintColor 等旧属性。
    /// - Parameter appearance: 标准外观。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func standardAppearance(_ appearance: UITabBarAppearance) -> Chain<Base> {
        base.standardAppearance = appearance
        return self
    }

    /// 设置滚动到边缘时的外观（iOS 15+）。
    /// 等价 `base.scrollEdgeAppearance = appearance`。
    /// - Parameter appearance: 滚动边缘外观。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func scrollEdgeAppearance(_ appearance: UITabBarAppearance?) -> Chain<Base> {
        base.scrollEdgeAppearance = appearance
        return self
    }
}

// MARK: - UIToolbar

/// 工具条 `UIToolbar` 的链式配置。
public extension Chain where Base: UIToolbar {

    /// 设置栏的整体风格（`.default` / `.black`）。
    /// 等价 `base.barStyle = style`。
    /// - Parameter style: 栏风格。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func barStyle(_ style: UIBarStyle) -> Chain<Base> {
        base.barStyle = style
        return self
    }

    /// 设置栏是否半透明（等价 `base.isTranslucent = translucent`）。
    /// - Parameter translucent: 是否半透明。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isTranslucent(_ translucent: Bool) -> Chain<Base> {
        base.isTranslucent = translucent
        return self
    }

    /// 设置栏的背景色调（iOS 15+ 起推荐改用外观组 `standardAppearance`）。
    /// 等价 `base.barTintColor = color`。
    /// - Parameter color: 背景色调。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func barTintColor(_ color: UIColor?) -> Chain<Base> {
        base.barTintColor = color
        return self
    }

    /// 批量设置工具条项。
    /// 等价 `base.setItems(items, animated:)`。
    /// - Parameters:
    ///   - items: 工具条项数组。
    ///   - animated: 是否带动画。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func items(_ items: [UIBarButtonItem]?, animated: Bool) -> Chain<Base> {
        base.setItems(items, animated: animated)
        return self
    }

    /// 设置工具条代理（等价 `base.delegate = delegate`）。
    /// - Parameter delegate: 工具条代理。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func delegate(_ delegate: UIToolbarDelegate?) -> Chain<Base> {
        base.delegate = delegate
        return self
    }

    // MARK: 外观组（iOS 15+）

    /// 设置标准外观（iOS 15+）。
    ///
    /// 外观组走现代路径：用 `UIToolbarAppearance` 一次性配置背景、文字等，
    /// 替代逐个设置 barTintColor 等旧属性。
    /// - Parameter appearance: 标准外观。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func standardAppearance(_ appearance: UIToolbarAppearance) -> Chain<Base> {
        base.standardAppearance = appearance
        return self
    }

    /// 设置紧凑栏外观（iOS 15+）。
    /// 等价 `base.compactAppearance = appearance`。
    /// - Parameter appearance: 紧凑外观。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func compactAppearance(_ appearance: UIToolbarAppearance?) -> Chain<Base> {
        base.compactAppearance = appearance
        return self
    }

    /// 设置滚动到边缘时的外观（iOS 15+）。
    /// 等价 `base.scrollEdgeAppearance = appearance`。
    /// - Parameter appearance: 滚动边缘外观。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func scrollEdgeAppearance(_ appearance: UIToolbarAppearance?) -> Chain<Base> {
        base.scrollEdgeAppearance = appearance
        return self
    }

    /// 设置紧凑栏滚动到边缘时的外观（iOS 15+）。
    /// 等价 `base.compactScrollEdgeAppearance = appearance`。
    /// - Parameter appearance: 滚动边缘外观。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func compactScrollEdgeAppearance(_ appearance: UIToolbarAppearance?) -> Chain<Base> {
        base.compactScrollEdgeAppearance = appearance
        return self
    }
}