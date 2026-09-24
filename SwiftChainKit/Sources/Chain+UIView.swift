//
//  Chain+UIView.swift
//  SwiftChainKit
//
//  基类属性：布局几何、显示、触摸、图层、无障碍 —— 所有 UIKit 视图通用。
//  `layer.*` 的圆角/边框/阴影收敛成别名，避免整条链里到处写 `.layer.xxx`。

import UIKit

/// `UIView` 基类属性扩展：布局几何、显示、触摸、图层、无障碍 —— 所有 UIKit 视图通用。
public extension Chain where Base: UIView {

    // MARK: - 布局与几何

    /// 设置视图在父视图坐标系中的位置与尺寸。
    ///
    /// 等价给 `base.frame` 赋值。
    /// - Parameter frame: 新的帧矩形。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func frame(_ frame: CGRect) -> Chain<Base> {
        base.frame = frame
        return self
    }

    /// 设置视图自身坐标系内的范围与原点。
    ///
    /// 注意 `bounds.origin` 的搬移会整体偏移子视图布局，等价给 `base.bounds` 赋值。
    /// - Parameter bounds: 新的范围矩形。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func bounds(_ bounds: CGRect) -> Chain<Base> {
        base.bounds = bounds
        return self
    }

    /// 设置视图中心点在父视图坐标系中的位置。
    ///
    /// 等价给 `base.center` 赋值。
    /// - Parameter center: 新的中心点。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func center(_ center: CGPoint) -> Chain<Base> {
        base.center = center
        return self
    }

    /// 设置内容缩放因子（适配 @2x / @3x 屏幕）。
    ///
    /// 等价给 `base.contentScaleFactor` 赋值。
    /// - Parameter scale: 缩放因子，通常为 1.0 / 2.0 / 3.0。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func contentScaleFactor(_ scale: CGFloat) -> Chain<Base> {
        base.contentScaleFactor = scale
        return self
    }

    /// 设置 autoresizing 布局下的缩放掩码（`.flexibleWidth`、`.flexibleHeight` 等）。
    ///
    /// 等价给 `base.autoresizingMask` 赋值；用 Auto Layout 时通常无需设置。
    /// - Parameter mask: 自动缩放掩码。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func autoresizingMask(_ mask: UIView.AutoresizingMask) -> Chain<Base> {
        base.autoresizingMask = mask
        return self
    }

    /// 控制尺寸变化时是否自动调整子视图（autoresizing 布局体系下生效）。
    ///
    /// 等价给 `base.autoresizesSubviews` 赋值。
    /// - Parameter autoresizes: 是否自动调整子视图。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func autoresizesSubviews(_ autoresizes: Bool) -> Chain<Base> {
        base.autoresizesSubviews = autoresizes
        return self
    }

    /// 设置是否由系统根据 autoresizingMask 自动生成 Auto Layout 约束。
    ///
    /// 等价 `base.translatesAutoresizingMaskIntoConstraints = allows`。
    /// 默认为 `true`；使用 SnapKit 等约束库时通常需要置 `false`，
    /// 快捷方法 `.autolayout()` 等价本方法传 `false`。
    ///
    /// - Note: `requiresConstraintBasedLayout` 是 `UIView` 的 get-only 类级属性
    ///   （由子类 override 声明「自身依赖基于约束的布局」），实例上无可写语义，
    ///   不属于链式 setter 范畴，故本库不提供对应的链方法。
    /// - Parameter allows: 是否自动生成约束。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func translatesAutoresizingMaskIntoConstraints(_ allows: Bool) -> Chain<Base> {
        base.translatesAutoresizingMaskIntoConstraints = allows
        return self
    }

    // MARK: - 显示与内容

    /// 设置是否隐藏视图。
    ///
    /// 等价给 `base.isHidden` 赋值。
    /// - Parameter hidden: 是否隐藏。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isHidden(_ hidden: Bool) -> Chain<Base> {
        base.isHidden = hidden
        return self
    }

    /// 设置视图不透明度。
    ///
    /// 等价给 `base.alpha` 赋值，取值 0.0（透明）~ 1.0（不透明）。
    /// - Parameter value: 不透明度数值。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func alpha(_ value: CGFloat) -> Chain<Base> {
        base.alpha = value
        return self
    }

    /// 设置背景色。
    ///
    /// 等价给 `base.backgroundColor` 赋值。
    /// - Parameter color: 背景色，传 `nil` 清除背景色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func backgroundColor(_ color: UIColor?) -> Chain<Base> {
        base.backgroundColor = color
        return self
    }

    /// 设置主题色（影响子视图默认的 tint 继承与高亮表现）。
    ///
    /// 等价给 `base.tintColor` 赋值。
    /// - Parameter color: 主题色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func tintColor(_ color: UIColor?) -> Chain<Base> {
        base.tintColor = color
        return self
    }

    /// 设置 tint 调整模式（正常 / 变暗 / 自动推断，用于弹窗压暗背景等场景）。
    ///
    /// 等价给 `base.tintAdjustmentMode` 赋值。
    /// - Parameter mode: 调整模式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func tintAdjustmentMode(_ mode: UIView.TintAdjustmentMode) -> Chain<Base> {
        base.tintAdjustmentMode = mode
        return self
    }

    /// 设置是否裁剪超出边界的子视图内容。
    ///
    /// 等价给 `base.clipsToBounds` 赋值（与 `layer.masksToBounds` 是同一属性）。
    /// - Parameter clips: 是否裁剪。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func clipsToBounds(_ clips: Bool) -> Chain<Base> {
        base.clipsToBounds = clips
        return self
    }

    /// 设置内容绘制 / 拉伸方式（居中、等比缩放、平铺等）。
    ///
    /// 等价给 `base.contentMode` 赋值。
    /// - Parameter mode: 内容模式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func contentMode(_ mode: UIView.ContentMode) -> Chain<Base> {
        base.contentMode = mode
        return self
    }

    /// 设置是否不透明（`true` 提示系统可跳过混合，常配合不透明背景提升渲染性能）。
    ///
    /// 等价给 `base.isOpaque` 赋值。
    /// - Parameter opaque: 是否不透明。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isOpaque(_ opaque: Bool) -> Chain<Base> {
        base.isOpaque = opaque
        return self
    }

    /// 设置是否响应用户交互（触摸、手势）。
    ///
    /// 等价给 `base.isUserInteractionEnabled` 赋值。
    /// - Parameter enabled: 是否启用交互。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isUserInteractionEnabled(_ enabled: Bool) -> Chain<Base> {
        base.isUserInteractionEnabled = enabled
        return self
    }

    /// 设置是否允许同时接收多点触摸事件。
    ///
    /// 等价给 `base.isMultipleTouchEnabled` 赋值。
    /// - Parameter enabled: 是否允许多点触摸。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isMultipleTouchEnabled(_ enabled: Bool) -> Chain<Base> {
        base.isMultipleTouchEnabled = enabled
        return self
    }

    /// 设置触摸是否独占（同一窗口内一次只响应一个触摸序列）。
    ///
    /// 等价给 `base.isExclusiveTouch` 赋值，多按钮同屏可点场景常置 `true`。
    /// - Parameter exclusive: 是否独占触摸。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isExclusiveTouch(_ exclusive: Bool) -> Chain<Base> {
        base.isExclusiveTouch = exclusive
        return self
    }

    /// 设置整数标签（配合 `viewWithTag(_:)` 查找子视图）。
    ///
    /// 等价给 `base.tag` 赋值。
    /// - Parameter tag: 新标签值。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func tag(_ tag: Int) -> Chain<Base> {
        base.tag = tag
        return self
    }

    /// 设置 2D 仿射变换（平移 / 缩放 / 旋转）。
    ///
    /// 等价给 `base.transform` 赋值。
    /// - Parameter transform: 仿射变换。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func transform(_ transform: CGAffineTransform) -> Chain<Base> {
        base.transform = transform
        return self
    }

    /// 设置 3D 变换（含透视的翻转、绕轴旋转等）。
    ///
    /// 等价给 `base.transform3D` 赋值。
    /// - Parameter transform: 3D 变换矩阵。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func transform3D(_ transform: CATransform3D) -> Chain<Base> {
        base.transform3D = transform
        return self
    }

    /// 设置内容排布语义方向（LTR / RTL / 自动推断）。
    ///
    /// 等价给 `base.semanticContentAttribute` 赋值，影响整棵视图布局镜像、行为全局可见。
    /// - Parameter attribute: 语义内容属性。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func semanticContentAttribute(_ attribute: UISemanticContentAttribute) -> Chain<Base> {
        base.semanticContentAttribute = attribute
        return self
    }

    // MARK: - 布局边距（Auto Layout 通用配置）

    /// 设置布局边距（Auto Layout 参考 `layoutMarginsGuide` 时生效）。
    ///
    /// 等价给 `base.layoutMargins` 赋值。
    /// - Parameter insets: 四边内边距。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func layoutMargins(_ insets: UIEdgeInsets) -> Chain<Base> {
        base.layoutMargins = insets
        return self
    }

    /// 设置是否继承并传播父视图的布局边距。
    ///
    /// 等价给 `base.preservesSuperviewLayoutMargins` 赋值。
    /// - Parameter preserves: 是否保持父视图边距。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func preservesSuperviewLayoutMargins(_ preserves: Bool) -> Chain<Base> {
        base.preservesSuperviewLayoutMargins = preserves
        return self
    }

    /// 设置布局边距是否自动并入安全区（刘海屏避开凹口）。
    ///
    /// 等价给 `base.insetsLayoutMarginsFromSafeArea` 赋值。
    /// - Parameter insets: 是否按安全区调整边距。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func insetsLayoutMarginsFromSafeArea(_ insets: Bool) -> Chain<Base> {
        base.insetsLayoutMarginsFromSafeArea = insets
        return self
    }

    // MARK: - 图层（圆角 / 边框 / 阴影）

    /// 设置圆角半径（作用于 `layer.cornerRadius`）。
    ///
    /// 等价 `base.layer.cornerRadius = radius`。
    /// - Parameter radius: 圆角半径。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func cornerRadius(_ radius: CGFloat) -> Chain<Base> {
        base.layer.cornerRadius = radius
        return self
    }

    /// 设置边框宽度（作用于 `layer.borderWidth`）。
    ///
    /// 等价 `base.layer.borderWidth = width`。
    /// - Parameter width: 边框宽度。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func borderWidth(_ width: CGFloat) -> Chain<Base> {
        base.layer.borderWidth = width
        return self
    }

    /// 设置边框颜色（作用于 `layer.borderColor`，自动取出 `cgColor`）。
    ///
    /// 等价 `base.layer.borderColor = color?.cgColor`。
    /// - Parameter color: 边框颜色，传 `nil` 清空边框色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func borderColor(_ color: UIColor?) -> Chain<Base> {
        base.layer.borderColor = color?.cgColor
        return self
    }

    /// 一次设置边框宽度与边框颜色（常见组合：头像、卡片、状态点）。
    ///
    /// 注意只设边框，圆角请另用 `cornerRadius(_:)`。
    /// - Parameters:
    ///   - width: 边框宽度。
    ///   - color: 边框颜色，传 `nil` 清空边框色。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func border(_ width: CGFloat, color: UIColor?) -> Chain<Base> {
        base.layer.borderWidth = width
        base.layer.borderColor = color?.cgColor
        return self
    }

    /// 设置子视图超出边界是否裁剪（作用于 `layer.masksToBounds`）。
    ///
    /// 需要阴影外发光时通常置 `false`；注意圆角裁剪与阴影外发光不可兼得。
    /// - Parameter masks: 是否裁剪。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func masksToBounds(_ masks: Bool) -> Chain<Base> {
        base.layer.masksToBounds = masks
        return self
    }

    /// 设置阴影颜色（作用于 `layer.shadowColor`）。
    ///
    /// 等价 `base.layer.shadowColor = color?.cgColor`。
    /// - Parameter color: 阴影颜色，传 `nil` 清空。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func shadowColor(_ color: UIColor?) -> Chain<Base> {
        base.layer.shadowColor = color?.cgColor
        return self
    }

    /// 设置阴影不透明度（作用于 `layer.shadowOpacity`，0.0~1.0，大于 0 才可见）。
    ///
    /// 等价 `base.layer.shadowOpacity = opacity`。
    /// - Parameter opacity: 阴影不透明度。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func shadowOpacity(_ opacity: Float) -> Chain<Base> {
        base.layer.shadowOpacity = opacity
        return self
    }

    /// 设置阴影模糊半径（作用于 `layer.shadowRadius`）。
    ///
    /// 等价 `base.layer.shadowRadius = radius`。
    /// - Parameter radius: 阴影模糊半径。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func shadowRadius(_ radius: CGFloat) -> Chain<Base> {
        base.layer.shadowRadius = radius
        return self
    }

    /// 设置阴影偏移（作用于 `layer.shadowOffset`）。
    ///
    /// 等价 `base.layer.shadowOffset = offset`。
    /// - Parameter offset: 阴影偏移量。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func shadowOffset(_ offset: CGSize) -> Chain<Base> {
        base.layer.shadowOffset = offset
        return self
    }

    /// 设置图层 Z 轴位置（决定兄弟视图的叠放顺序）。
    ///
    /// 等价 `base.layer.zPosition = position`。
    /// - Parameter position: Z 轴坐标。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func zPosition(_ position: CGFloat) -> Chain<Base> {
        base.layer.zPosition = position
        return self
    }

    // MARK: - 布局优先级（先取再说：替代 setContentHuggingPriority 两段式）

    /// 设置抗拉伸优先级（content hugging），数值越高越不愿被 Auto Layout 拉大。
    ///
    /// 等价 `base.setContentHuggingPriority(priority, for: axis)`。
    /// - Parameters:
    ///   - priority: 布局优先级（`.required`、`.defaultHigh` 等）。
    ///   - axis: 作用的轴向（`.horizontal` / `.vertical`）。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func hugging(_ priority: UILayoutPriority, for axis: NSLayoutConstraint.Axis) -> Chain<Base> {
        base.setContentHuggingPriority(priority, for: axis)
        return self
    }

    /// 设置抗压缩优先级（compression resistance），数值越高越不愿被压小。
    ///
    /// 等价 `base.setContentCompressionResistancePriority(priority, for: axis)`。
    /// - Parameters:
    ///   - priority: 布局优先级。
    ///   - axis: 作用的轴向（`.horizontal` / `.vertical`）。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func compressionResistance(_ priority: UILayoutPriority, for axis: NSLayoutConstraint.Axis) -> Chain<Base> {
        base.setContentCompressionResistancePriority(priority, for: axis)
        return self
    }

    // MARK: - 无障碍

    /// 设置是否作为独立的无障碍元素（供旁白聚焦朗读）。
    ///
    /// 等价给 `base.isAccessibilityElement` 赋值。
    /// - Parameter element: 是否作为无障碍元素。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isAccessibilityElement(_ element: Bool) -> Chain<Base> {
        base.isAccessibilityElement = element
        return self
    }

    /// 设置无障碍朗读标签（旁白读到的主要文本）。
    ///
    /// 等价给 `base.accessibilityLabel` 赋值，传 `nil` 时退回默认推导文本。
    /// - Parameter label: 无障碍标签。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func accessibilityLabel(_ label: String?) -> Chain<Base> {
        base.accessibilityLabel = label
        return self
    }

    /// 设置无障碍朗读值（配合标签使用，如进度、开关状态）。
    ///
    /// 等价给 `base.accessibilityValue` 赋值。
    /// - Parameter value: 无障碍值。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func accessibilityValue(_ value: String?) -> Chain<Base> {
        base.accessibilityValue = value
        return self
    }

    /// 设置无障碍操作提示（旁白在操作前朗读的指引）。
    ///
    /// 等价给 `base.accessibilityHint` 赋值。
    /// - Parameter hint: 无障碍提示文本。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func accessibilityHint(_ hint: String?) -> Chain<Base> {
        base.accessibilityHint = hint
        return self
    }

    /// 设置无障碍特征（按钮、告警、可调整等，可组合）。
    ///
    /// 等价给 `base.accessibilityTraits` 赋值。
    /// - Parameter traits: 无障碍特征集合。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func accessibilityTraits(_ traits: UIAccessibilityTraits) -> Chain<Base> {
        base.accessibilityTraits = traits
        return self
    }

    /// 设置无障碍标识符（自动化测试与 UI 查找用，不参与朗读）。
    ///
    /// 等价给 `base.accessibilityIdentifier` 赋值。
    /// - Parameter identifier: 无障碍标识符。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func accessibilityIdentifier(_ identifier: String?) -> Chain<Base> {
        base.accessibilityIdentifier = identifier
        return self
    }

    // MARK: - 动作（system extension 形态的方法：把无返回值的调用收进链）

    /// 挂接一个手势识别器：等价 `base.addGestureRecognizer(gesture)`。
    ///
    /// 手势本身的链式配置另见 `UIGestureRecognizer.chain().added(to:)`。
    /// - Parameter gesture: 要挂接的手势识别器。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func addGestureRecognizer(_ gesture: UIGestureRecognizer) -> Chain<Base> {
        base.addGestureRecognizer(gesture)
        return self
    }

    /// 移除一个手势识别器：等价 `base.removeGestureRecognizer(gesture)`。
    ///
    /// 与 `addGestureRecognizer(_:)` 配对使用。
    /// - Parameter gesture: 要移除的手势识别器。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func removeGestureRecognizer(_ gesture: UIGestureRecognizer) -> Chain<Base> {
        base.removeGestureRecognizer(gesture)
        return self
    }

    /// 立即同步刷新布局树：等价 `base.layoutIfNeeded()`。
    ///
    /// 常用于读取 `frame` 前强制完成待定的布局计算。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func layoutIfNeeded() -> Chain<Base> {
        base.layoutIfNeeded()
        return self
    }

    /// 标记布局待刷新，将计算推迟到下一个绘制周期。
    ///
    /// 与 `layoutIfNeeded()` 对应：一个标记、一个立即执行，都能进链。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func setNeedsLayout() -> Chain<Base> {
        base.setNeedsLayout()
        return self
    }

    /// 标记 Auto Layout 约束待重新计算（推迟到下一个更新周期）。
    ///
    /// 等价 `base.setNeedsUpdateConstraints()`。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func setNeedsUpdateConstraints() -> Chain<Base> {
        base.setNeedsUpdateConstraints()
        return self
    }

    /// 标记指定区域需要重绘（`draw(_:)` 会在绘制周期内被调用）。
    ///
    /// 等价 `base.setNeedsDisplay(rect)`。
    /// - Parameter rect: 需要重绘的区域。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func setNeedsDisplay(_ rect: CGRect) -> Chain<Base> {
        base.setNeedsDisplay(rect)
        return self
    }

    /// 让视图依照内容自适应尺寸。
    ///
    /// 等价 `base.sizeToFit()`（会直接改动 `frame`，Auto Layout 场景慎用）。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func sizeToFit() -> Chain<Base> {
        base.sizeToFit()
        return self
    }

    /// 告知系统内容固有尺寸（`intrinsicContentSize`）已变化。
    ///
    /// 等价 `base.invalidateIntrinsicContentSize()`，常用于自定义视图内部数据更新后。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func invalidateIntrinsicContentSize() -> Chain<Base> {
        base.invalidateIntrinsicContentSize()
        return self
    }
}