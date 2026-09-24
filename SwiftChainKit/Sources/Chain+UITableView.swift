//
//  Chain+UITableView.swift
//  SwiftChainKit
//
//  列表：复用池注册、行高/分隔线、编辑态、选择行为、表头表尾、索引栏、拖拽/预取。
//  delegate 保留（diffable 时代 dataSource 交给 DiffableDataSource，这里仍可按需配）。

import UIKit

/// 列表配置链：复用池注册、行高/分隔线、编辑态、选择行为、表头表尾、索引栏、拖拽/预取。
///
/// 滚动类属性（偏移/内边距/指示条）来自 `Chain+UIScrollView` 基座。
/// delegate 保留（diffable 时代 dataSource 交给 DiffableDataSource，这里仍可按需配）。
public extension Chain where Base: UITableView {

    /// 设置列表委托对象。
    ///
    /// 等价直接给 `UITableView.delegate` 赋值；可传 nil 清空。
    /// - Parameter delegate: 委托对象。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func delegate(_ delegate: UITableViewDelegate?) -> Chain<Base> {
        base.delegate = delegate
        return self
    }

    /// 设置列表数据源对象。
    ///
    /// 等价直接给 `UITableView.dataSource` 赋值；可传 nil 清空。
    /// - Parameter dataSource: 数据源对象。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func dataSource(_ dataSource: UITableViewDataSource?) -> Chain<Base> {
        base.dataSource = dataSource
        return self
    }

    /// 注册单元格类到复用池（等价 `UITableView.register(_:forCellReuseIdentifier:)`）。
    ///
    /// 与核心 API 同名但带 UIKit 精确标签 `forCellReuseIdentifier`。
    /// - Parameters:
    ///   - cellClass: 单元格类型，可传 nil 清除该标识符的注册。
    ///   - forCellReuseIdentifier: 复用标识符，需与出队时传入的一致。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func register(_ cellClass: AnyClass?, forCellReuseIdentifier: String) -> Chain<Base> {
        base.register(cellClass, forCellReuseIdentifier: forCellReuseIdentifier)
        return self
    }

    /// 注册表头/表尾视图类到复用池（等价 `UITableView.register(_:forHeaderFooterViewReuseIdentifier:)`）。
    ///
    /// 与核心 API 同名但带 UIKit 精确标签 `forHeaderFooterViewReuseIdentifier`。
    /// - Parameters:
    ///   - headerFooterClass: 视图类型，可传 nil 清除该标识符的注册。
    ///   - forHeaderFooterViewReuseIdentifier: 复用标识符，需与出队时传入的一致。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func register(_ headerFooterClass: AnyClass?, forHeaderFooterViewReuseIdentifier: String) -> Chain<Base> {
        base.register(headerFooterClass, forHeaderFooterViewReuseIdentifier: forHeaderFooterViewReuseIdentifier)
        return self
    }

    /// 设置行高。
    ///
    /// 注意：优先被委托的 `heightForRowAt` 覆盖，仅委托未实现时以该值生效。
    /// - Parameter height: 行高（点）。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func rowHeight(_ height: CGFloat) -> Chain<Base> {
        base.rowHeight = height
        return self
    }

    /// 设置预估行高（性能优化用，非精确高度）。
    /// - Parameter height: 预估行高。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func estimatedRowHeight(_ height: CGFloat) -> Chain<Base> {
        base.estimatedRowHeight = height
        return self
    }

    /// 设置区头（section header）高度。
    /// - Parameter height: 区头高度（点）。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func sectionHeaderHeight(_ height: CGFloat) -> Chain<Base> {
        base.sectionHeaderHeight = height
        return self
    }

    /// 设置区尾（section footer）高度。
    /// - Parameter height: 区尾高度（点）。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func sectionFooterHeight(_ height: CGFloat) -> Chain<Base> {
        base.sectionFooterHeight = height
        return self
    }

    /// 设置预估区头高度（性能优化用，非精确高度）。
    /// - Parameter height: 预估区头高度。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func estimatedSectionHeaderHeight(_ height: CGFloat) -> Chain<Base> {
        base.estimatedSectionHeaderHeight = height
        return self
    }

    /// 设置预估区尾高度（性能优化用，非精确高度）。
    /// - Parameter height: 预估区尾高度。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func estimatedSectionFooterHeight(_ height: CGFloat) -> Chain<Base> {
        base.estimatedSectionFooterHeight = height
        return self
    }

    /// 设置分隔线样式。
    /// - Parameter style: `.none` 隐藏、`.singleLine` 单线、`.singleLineEtched` 蚀刻线。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func separatorStyle(_ style: UITableViewCell.SeparatorStyle) -> Chain<Base> {
        base.separatorStyle = style
        return self
    }

    /// 设置分隔线颜色（`separatorStyle` 非 `.none` 时可见）。
    /// - Parameter color: 分隔线颜色，可传 nil 恢复默认。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func separatorColor(_ color: UIColor?) -> Chain<Base> {
        base.separatorColor = color
        return self
    }

    /// 设置分隔线视觉特效（如模糊效果）。
    /// - Parameter effect: `UIVisualEffect?`，可传 nil 清除特效。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func separatorEffect(_ effect: UIVisualEffect?) -> Chain<Base> {
        base.separatorEffect = effect
        return self
    }

    /// 设置分隔线内边距。
    /// - Parameter inset: 距 cell 边缘的内边距。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func separatorInset(_ inset: UIEdgeInsets) -> Chain<Base> {
        base.separatorInset = inset
        return self
    }

    /// cell 布局边距是否跟随可读宽度（iPad 分栏宽边距对齐场景）。
    /// - Parameter follows: 传 true 让 cell 边距与可读宽度对齐。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func cellLayoutMarginsFollowReadableWidth(_ follows: Bool) -> Chain<Base> {
        base.cellLayoutMarginsFollowReadableWidth = follows
        return self
    }

    /// cell 内容视图是否缩进到安全区（iOS 11+）。
    /// - Parameter insets: 传 true 让内容避开刘海/圆角等非安全区。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func insetsContentViewsToSafeArea(_ insets: Bool) -> Chain<Base> {
        base.insetsContentViewsToSafeArea = insets
        return self
    }

    // MARK: - 选择行为

    /// 设置是否允许选中（默认 true）。
    /// - Parameter allows: 传 false 关闭整表选中。
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

    /// 编辑态下是否仍允许选中（默认 true）。
    /// - Parameter allows: 传 false 在编辑态禁用选中。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func allowsSelectionDuringEditing(_ allows: Bool) -> Chain<Base> {
        base.allowsSelectionDuringEditing = allows
        return self
    }

    /// 编辑态下是否仍允许多选（默认 false）。
    /// - Parameter allows: 传 true 在编辑态打开多选。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func allowsMultipleSelectionDuringEditing(_ allows: Bool) -> Chain<Base> {
        base.allowsMultipleSelectionDuringEditing = allows
        return self
    }

    // MARK: - 编辑态 / 表头表尾 / 索引

    /// 设置编辑态开关（无动画版本）。
    ///
    /// 等价直接给 `base.isEditing` 赋值；需要动画请看 `editing(_:animated:)`。
    /// - Parameter editing: 传 true 进入编辑态。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isEditing(_ editing: Bool) -> Chain<Base> {
        base.isEditing = editing
        return self
    }

    /// 带动画切换编辑态（等价 `UITableView.setEditing(_:animated:)`）。
    /// - Parameters:
    ///   - editing: 传 true 进入编辑态。
    ///   - animated: 是否动画过渡。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func editing(_ editing: Bool, animated: Bool) -> Chain<Base> {
        base.setEditing(editing, animated: animated)
        return self
    }

    /// 设置表头视图。
    /// - Parameter view: 表头视图，可传 nil 移除。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func tableHeaderView(_ view: UIView?) -> Chain<Base> {
        base.tableHeaderView = view
        return self
    }

    /// 设置表尾视图。
    /// - Parameter view: 表尾视图，可传 nil 移除。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func tableFooterView(_ view: UIView?) -> Chain<Base> {
        base.tableFooterView = view
        return self
    }

    /// 设置表格背景视图（位于 cell 之下）。
    /// - Parameter view: 背景视图，可传 nil 恢复默认背景。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func backgroundView(_ view: UIView?) -> Chain<Base> {
        base.backgroundView = view
        return self
    }

    /// 设置索引栏文字颜色。
    /// - Parameter color: 索引文字颜色，可传 nil 恢复默认。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func sectionIndexColor(_ color: UIColor?) -> Chain<Base> {
        base.sectionIndexColor = color
        return self
    }

    /// 设置索引栏背景色。
    /// - Parameter color: 索引栏背景色，可传 nil 恢复默认。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func sectionIndexBackgroundColor(_ color: UIColor?) -> Chain<Base> {
        base.sectionIndexBackgroundColor = color
        return self
    }

    /// 设置索引栏拖动时的高亮背景色。
    /// - Parameter color: 拖动高亮背景色，可传 nil 恢复默认。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func sectionIndexTrackingBackgroundColor(_ color: UIColor?) -> Chain<Base> {
        base.sectionIndexTrackingBackgroundColor = color
        return self
    }

    /// 未达该行数时不显示右侧索引栏（默认 0 恒显示）。
    /// - Parameter count: 触发展示索引栏的最小行数。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func sectionIndexMinimumDisplayRowCount(_ count: Int) -> Chain<Base> {
        base.sectionIndexMinimumDisplayRowCount = count
        return self
    }

    // MARK: - 预取 / 拖拽

    /// 预取数据源（iOS 10+）：滚入前提前加载，一般配 DiffableDataSource 时保持 nil。
    /// - Parameter dataSource: 预取委托对象，可传 nil 关闭预取。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func prefetchDataSource(_ dataSource: UITableViewDataSourcePrefetching?) -> Chain<Base> {
        base.prefetchDataSource = dataSource
        return self
    }

    /// 是否开启拖拽交互（iOS 11+，配合 dragDelegate/dropDelegate 使用）。
    /// - Parameter enabled: 传 true 打开拖拽。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func dragInteractionEnabled(_ enabled: Bool) -> Chain<Base> {
        base.dragInteractionEnabled = enabled
        return self
    }

    /// 设置拖拽代理（iOS 11+，配合 `dragInteractionEnabled(true)` 使用）。
    /// - Parameter delegate: `UITableViewDragDelegate`，可传 nil 清除。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func dragDelegate(_ delegate: UITableViewDragDelegate?) -> Chain<Base> {
        base.dragDelegate = delegate
        return self
    }

    /// 设置放下（drop）代理（iOS 11+，配合 `dragInteractionEnabled(true)` 使用）。
    /// - Parameter delegate: `UITableViewDropDelegate`，可传 nil 清除。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func dropDelegate(_ delegate: UITableViewDropDelegate?) -> Chain<Base> {
        base.dropDelegate = delegate
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
}