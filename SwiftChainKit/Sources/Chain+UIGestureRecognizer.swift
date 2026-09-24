//
//  Chain+UIGestureRecognizer.swift
//  SwiftChainKit
//
//  手势：通用属性 + 各子类工厂与独有参数。手势链配合 `.added(to:)` 归位：
//
//     UITapGestureRecognizer.chain()
//         .numberOfTapsRequired(2)
//         .target(self, action: #selector(didDoubleTap))
//         .added(to: card)   // 等价 card.addGestureRecognizer(gesture)

import UIKit

// MARK: - 挂载（手势专用：等价 `view.addGestureRecognizer(base)`）

/// 手势挂载基座：`.added(to:)` 归位是手势链的收尾一步。
///
/// 手势不是 UIView，不能用 UIView 基座的 `added(to:)`，这里单独给一版。
public extension Chain where Base: UIGestureRecognizer {
    /// 把手势挂到指定视图上。
    ///
    /// 等价 `view.addGestureRecognizer(base)`。手势专用：手势不是 UIView，
    /// 不能用 UIView 基座的 `added(to:)`，这里单独给一版归位入口。
    /// - Parameter view: 要挂载手势的目标视图。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func added(to view: UIView) -> Chain<Base> {
        view.addGestureRecognizer(base)
        return self
    }
}

// MARK: - 工厂（各手势一个，进链即得 Chain<具体子类>）

/// 轻点手势（tap）的链式工厂。
extension UITapGestureRecognizer {
    /// 创建轻点手势并进入链。
    ///
    /// 手势不是 UIView，没有 `.chain()`，静态工厂是进入手势链的唯一入口。
    /// - Returns: 返回可链式设置的 `Chain<UITapGestureRecognizer>`。
    @MainActor
    public static func chain() -> Chain<UITapGestureRecognizer> { Chain(UITapGestureRecognizer()) }
}
/// 长按手势（long press）的链式工厂。
extension UILongPressGestureRecognizer {
    /// 创建长按手势并进入链。
    ///
    /// 手势不是 UIView，没有 `.chain()`，静态工厂是进入手势链的唯一入口。
    /// - Returns: 返回可链式设置的 `Chain<UILongPressGestureRecognizer>`。
    @MainActor
    public static func chain() -> Chain<UILongPressGestureRecognizer> { Chain(UILongPressGestureRecognizer()) }
}
/// 平移/拖拽手势（pan）的链式工厂。
extension UIPanGestureRecognizer {
    /// 创建平移手势并进入链。
    ///
    /// 手势不是 UIView，没有 `.chain()`，静态工厂是进入手势链的唯一入口。
    /// - Returns: 返回可链式设置的 `Chain<UIPanGestureRecognizer>`。
    @MainActor
    public static func chain() -> Chain<UIPanGestureRecognizer> { Chain(UIPanGestureRecognizer()) }
}
/// 滑动手势（swipe）的链式工厂。
extension UISwipeGestureRecognizer {
    /// 创建滑动手势并进入链。
    ///
    /// 手势不是 UIView，没有 `.chain()`，静态工厂是进入手势链的唯一入口。
    /// - Returns: 返回可链式设置的 `Chain<UISwipeGestureRecognizer>`。
    @MainActor
    public static func chain() -> Chain<UISwipeGestureRecognizer> { Chain(UISwipeGestureRecognizer()) }
}
/// 捏合缩放手势（pinch）的链式工厂。
extension UIPinchGestureRecognizer {
    /// 创建捏合缩放手势并进入链。
    ///
    /// 手势不是 UIView，没有 `.chain()`，静态工厂是进入手势链的唯一入口。
    /// - Returns: 返回可链式设置的 `Chain<UIPinchGestureRecognizer>`。
    @MainActor
    public static func chain() -> Chain<UIPinchGestureRecognizer> { Chain(UIPinchGestureRecognizer()) }
}
/// 旋转手势（rotation）的链式工厂。
extension UIRotationGestureRecognizer {
    /// 创建旋转手势并进入链。
    ///
    /// 手势不是 UIView，没有 `.chain()`，静态工厂是进入手势链的唯一入口。
    /// - Returns: 返回可链式设置的 `Chain<UIRotationGestureRecognizer>`。
    @MainActor
    public static func chain() -> Chain<UIRotationGestureRecognizer> { Chain(UIRotationGestureRecognizer()) }
}
/// 屏幕边缘滑动手势（screen edge pan）的链式工厂。
extension UIScreenEdgePanGestureRecognizer {
    /// 创建屏幕边缘滑动手势并进入链。
    ///
    /// 手势不是 UIView，没有 `.chain()`，静态工厂是进入手势链的唯一入口。
    /// - Returns: 返回可链式设置的 `Chain<UIScreenEdgePanGestureRecognizer>`。
    @MainActor
    public static func chain() -> Chain<UIScreenEdgePanGestureRecognizer> { Chain(UIScreenEdgePanGestureRecognizer()) }
}

// MARK: - 通用属性

/// 手势通用属性（所有 `UIGestureRecognizer` 子类共有的配置）。
public extension Chain where Base: UIGestureRecognizer {

    /// 手势是否启用（等价 `base.isEnabled = enabled`）。
    /// - Parameter enabled: 是否启用。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func isEnabled(_ enabled: Bool) -> Chain<Base> {
        base.isEnabled = enabled
        return self
    }

    /// 事件挂接：等价 `base.addTarget(target, action: action)`。
    /// - Parameters:
    ///   - target: 事件回调目标对象。
    ///   - action: 回调方法选择器。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func target(_ target: Any, action: Selector) -> Chain<Base> {
        base.addTarget(target, action: action)
        return self
    }

    /// 移除事件挂接：等价 `base.removeTarget(target, action: action)`。
    /// - Parameters:
    ///   - target: 欲移除的目标对象。
    ///   - action: 行为选择器；传 `nil` 表示移除该目标下的全部行为。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func removeTarget(_ target: Any, action: Selector?) -> Chain<Base> {
        base.removeTarget(target, action: action)
        return self
    }

    /// 设置手势代理（`gestureRecognizerShouldBegin` 等回调走这里）。
    ///
    /// 等价 `base.delegate = delegate`。
    /// - Parameter delegate: 手势代理。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func delegate(_ delegate: UIGestureRecognizerDelegate?) -> Chain<Base> {
        base.delegate = delegate
        return self
    }

    /// 设置手势名称（便于调试与批量管理，iOS 11+）。
    /// - Parameter name: 手势名称。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func name(_ name: String?) -> Chain<Base> {
        base.name = name
        return self
    }

    /// 识别手势时是否取消向视图传递触摸事件。
    ///
    /// 等价 `base.cancelsTouchesInView = cancels`；默认 `true`，通常无需改动。
    /// - Parameter cancels: 是否取消。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func cancelsTouchesInView(_ cancels: Bool) -> Chain<Base> {
        base.cancelsTouchesInView = cancels
        return self
    }

    /// 触摸「按下」事件是否延迟到手势识别失败后才派发给视图。
    /// - Parameter delays: 是否延迟。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func delaysTouchesBegan(_ delays: Bool) -> Chain<Base> {
        base.delaysTouchesBegan = delays
        return self
    }

    /// 触摸「抬起」事件是否延迟到手势识别失败后才派发给视图。
    /// - Parameter delays: 是否延迟。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func delaysTouchesEnded(_ delays: Bool) -> Chain<Base> {
        base.delaysTouchesEnded = delays
        return self
    }
}

// MARK: - 子类专属

/// 轻点手势（tap）独有参数。
public extension Chain where Base: UITapGestureRecognizer {

    /// 识别所需的点击次数（双击设为 2）。
    /// - Parameter count: 点击次数。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func numberOfTapsRequired(_ count: Int) -> Chain<Base> {
        base.numberOfTapsRequired = count
        return self
    }

    /// 同时参与手势识别所需的触摸点数。
    /// - Parameter count: 触摸点数。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func numberOfTouchesRequired(_ count: Int) -> Chain<Base> {
        base.numberOfTouchesRequired = count
        return self
    }
}

/// 长按手势（long press）独有参数。
public extension Chain where Base: UILongPressGestureRecognizer {

    /// 识别长按所需的最短按压时长（秒）。
    /// - Parameter duration: 最短按压时长。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func minimumPressDuration(_ duration: TimeInterval) -> Chain<Base> {
        base.minimumPressDuration = duration
        return self
    }

    /// 按压期间手指允许的最大位移（超出则识别失败）。
    /// - Parameter movement: 允许位移。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func allowableMovement(_ movement: CGFloat) -> Chain<Base> {
        base.allowableMovement = movement
        return self
    }

    /// 触发长按前需完成的点击次数。
    /// - Parameter count: 点击次数。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func numberOfTapsRequired(_ count: Int) -> Chain<Base> {
        base.numberOfTapsRequired = count
        return self
    }

    /// 同时参与长按识别的触摸点数。
    /// - Parameter count: 触摸点数。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func numberOfTouchesRequired(_ count: Int) -> Chain<Base> {
        base.numberOfTouchesRequired = count
        return self
    }
}

/// 平移手势（pan）独有参数。
public extension Chain where Base: UIPanGestureRecognizer {

    /// 识别平移所需的最少触摸点数。
    /// - Parameter count: 最少触摸点数。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func minimumNumberOfTouches(_ count: Int) -> Chain<Base> {
        base.minimumNumberOfTouches = count
        return self
    }

    /// 参与平移的最大触摸点数。
    /// - Parameter count: 最大触摸点数。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func maximumNumberOfTouches(_ count: Int) -> Chain<Base> {
        base.maximumNumberOfTouches = count
        return self
    }
}

/// 滑动手势（swipe）独有参数。
public extension Chain where Base: UISwipeGestureRecognizer {

    /// 滑动的识别方向：`.left` / `.right` / `.up` / `.down` 组合。
    /// - Parameter direction: 方向掩码。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func direction(_ direction: UISwipeGestureRecognizer.Direction) -> Chain<Base> {
        base.direction = direction
        return self
    }

    /// 参与滑动识别的触摸点数。
    /// - Parameter count: 触摸点数。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func numberOfTouchesRequired(_ count: Int) -> Chain<Base> {
        base.numberOfTouchesRequired = count
        return self
    }
}

/// 屏幕边缘滑动手势（screen edge pan）独有参数。
public extension Chain where Base: UIScreenEdgePanGestureRecognizer {

    /// 识别哪些屏幕边缘触发：`.left` / `.right` / `.top` / `.bottom` 组合（相对当前屏幕方向）。
    /// - Parameter edges: 屏幕边缘掩码。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func edges(_ edges: UIRectEdge) -> Chain<Base> {
        base.edges = edges
        return self
    }
}