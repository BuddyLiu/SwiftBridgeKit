//
//  Chain+UICollectionView.swift
//  SwiftChainKit
//
//  集合：工厂 + 复用注册 + 选择行为。滚动类属性（isScrollEnabled/内边距/指示条）来自
//  Chain+UIScrollView 基座，这里只放集合独有项。

import UIKit

/// 集合工厂入口：`UICollectionView.chain(layout:)` 以指定布局创建集合并进链。
public extension UICollectionView {
    /// 以指定布局创建 `UICollectionView` 进入链式设置。
    ///
    /// flow / paging 等布局在构造时传入（`UICollectionViewFlowLayout` 或自定义布局）。
    /// - Parameters:
    ///   - layout: 集合布局，决定内容排布方式。
    /// - Returns: 返回可链式设置的 `UICollectionView` 链。
    @MainActor
    static func chain(layout: UICollectionViewLayout) -> Chain<UICollectionView> {
        Chain(UICollectionView(frame: .zero, collectionViewLayout: layout))
    }
}

/// 集合配置链：复用注册、选择行为、预取/拖拽/焦点。
///
/// 滚动类属性（isScrollEnabled/内边距/指示条）来自 `Chain+UIScrollView` 基座，
/// 这里只放集合独有项。
public extension Chain where Base: UICollectionView {

    /// 设置集合委托对象。
    ///
    /// 等价直接给 `UICollectionView.delegate` 赋值；可传 nil 清空。
    /// - Parameter delegate: 委托对象。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func delegate(_ delegate: UICollectionViewDelegate?) -> Chain<Base> {
        base.delegate = delegate
        return self
    }

    /// 设置集合数据源对象。
    ///
    /// 等价直接给 `UICollectionView.dataSource` 赋值；可传 nil 清空。
    /// - Parameter dataSource: 数据源对象。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func dataSource(_ dataSource: UICollectionViewDataSource?) -> Chain<Base> {
        base.dataSource = dataSource
        return self
    }

    /// 注册单元格类到复用池（等价 `UICollectionView.register(_:forCellWithReuseIdentifier:)`）。
    ///
    /// 与核心 API 同名但带 UIKit 精确标签 `forCellWithReuseIdentifier`。
    /// - Parameters:
    ///   - cellClass: 单元格类型，可传 nil 清除该标识符的注册。
    ///   - forCellWithReuseIdentifier: 复用标识符，需与出队时传入的一致。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func register(_ cellClass: AnyClass?, forCellWithReuseIdentifier: String) -> Chain<Base> {
        base.register(cellClass, forCellWithReuseIdentifier: forCellWithReuseIdentifier)
        return self
    }

    /// 注册补充视图（区头/区尾等）到复用池（等价
    /// `UICollectionView.register(_:forSupplementaryViewOfKind:withReuseIdentifier:)`）。
    ///
    /// 与核心 API 同名但带 UIKit 精确标签 `forSupplementaryViewOfKind` / `withReuseIdentifier`。
    /// - Parameters:
    ///   - viewClass: 视图类型，可传 nil 清除该标识符的注册。
    ///   - kind: 补充视图种类（如 `UICollectionView.elementKindSectionHeader`）。
    ///   - identifier: 复用标识符，需与出队时传入的一致。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func register(_ viewClass: AnyClass?,
                  forSupplementaryViewOfKind kind: String,
                  withReuseIdentifier identifier: String) -> Chain<Base> {
        base.register(viewClass, forSupplementaryViewOfKind: kind, withReuseIdentifier: identifier)
        return self
    }

    /// 网格是否预取即将滚入的内容（性能开关，一般保持默认）。
    /// - Parameter enabled: 传 false 关闭预取以省内存。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isPrefetchingEnabled(_ enabled: Bool) -> Chain<Base> {
        base.isPrefetchingEnabled = enabled
        return self
    }

    /// 设置是否允许选中（默认 true）。
    /// - Parameter allows: 传 false 关闭整网格选中。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func allowsSelection(_ allows: Bool) -> Chain<Base> {
        base.allowsSelection = allows
        return self
    }

    /// 设置是否允许多选（默认 false）。
    /// - Parameter allows: 传 true 打开多选。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func allowsMultipleSelection(_ allows: Bool) -> Chain<Base> {
        base.allowsMultipleSelection = allows
        return self
    }

    /// 设置集合背景视图（位于内容之下）。
    /// - Parameter view: 背景视图，可传 nil 恢复默认背景。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func backgroundView(_ view: UIView?) -> Chain<Base> {
        base.backgroundView = view
        return self
    }

    // MARK: - 预取 / 拖拽 / 焦点

    /// 预取数据源（iOS 10+）：滚入前提前加载，一般配 DiffableDataSource 时保持 nil。
    /// - Parameter dataSource: 预取委托对象，可传 nil 关闭预取。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func prefetchDataSource(_ dataSource: UICollectionViewDataSourcePrefetching?) -> Chain<Base> {
        base.prefetchDataSource = dataSource
        return self
    }

    /// 是否开启单元格拖拽排布（iOS 11+）。
    /// - Parameter enabled: 传 true 打开拖拽重排。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func dragInteractionEnabled(_ enabled: Bool) -> Chain<Base> {
        base.dragInteractionEnabled = enabled
        return self
    }

    /// 焦点选中是否跟随（iOS 15+，tvOS 交互语义）。
    /// - Parameter follows: 传 true 让焦点移动带动选中。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func selectionFollowsFocus(_ follows: Bool) -> Chain<Base> {
        base.selectionFollowsFocus = follows
        return self
    }

    /// 集合是否符合区域焦点（iOS 15+，配合无头/键盘焦点导航）。
    /// - Parameter allows: 传 false 跳过该轮到焦点导航。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func allowsFocus(_ allows: Bool) -> Chain<Base> {
        base.allowsFocus = allows
        return self
    }
}