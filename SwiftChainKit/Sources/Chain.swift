//
//  Chain.swift
//  SwiftChainKit
//
//  点语法链式 DSL 的核心：`Chain<Base>` 是一个「配置外壳」，持有视图本体，
//  所有链方法都以 `返回 Chain<Base>` 的形态连接，最后用 `.build()` 取回本体。
//
//  Why this shape（参考 ZZFLEX 的改进点）：
//    · ZZFLEX 用 ObjC 的 category 直接挂方法，靠运行时 `id` 弱类型；
//      这里用 Swift 泛型 `Chain<Base>` 替 view 本体做配置层 ——
//      `Chain<UILabel>` 只暴露 UILabel 的方法，编译器拦得住误用。
//    · UIKit 视图的属性名（text/font/...）与方法名同名的声明是非法的
//      （`var text` 与 `func text(_:)` 不能共存），这正是 SnapKit 用 `snp`
//      命名空间的原因；`Chain` 外壳天然解决了这份命名冲突，不侵入 view 本体。
//    · `.also {}` 是逃生口：任何链上没覆盖的操作（自定义手势、布局、动画）
//      都能在链中间插入，链不因此断掉 —— 库只做「点语法设置」，不越权做
//      布局/约束魔法，保留给使用方。
//
//  全体方法 @MainActor：UIKit 视图只在主线程碰（与组件包 zero-warning 约定一致）。

import UIKit

/// 点语法链式外壳。持有一个 `Base`（一般就是某个 UIKit 视图类）。
public struct Chain<Base> {
    /// 被配置的视图本体。
    public let base: Base

    /// 创建链式外壳，内部持有待配置的视图本体。
    ///
    /// 一般无需直接调用，走 `view.chain()` 入口即可。
    /// - Parameter base: 被配置的视图本体。
    public init(_ base: Base) {
        self.base = base
    }

    /// 链终点：取回配置完成的本体。
    ///
    /// 不接 `.build()` 时整条链只是被丢弃的临时值（无副作用要求时可用），
    /// 但惯例是链尾 `let label = UILabel().chain().text("x").build()`。
    /// - Returns: 配置完成的 `Base` 本体。
    @discardableResult
    public func build() -> Base {
        base
    }

    /// Kotlin `also` 语义的逃生口：链中间插入任意副作用（手势、约束、log…），
    /// 执行完后返回自身，链可以继续接下去。
    ///
    ///     let card = UIView().chain()
    ///         .backgroundColor(.systemGray6)
    ///         .also { $0.addGestureRecognizer(UITapGestureRecognizer(...)) }
    ///         .cornerRadius(10)
    ///         .build()
    ///
    /// - Parameter f: 以被配置视图 `base` 为参数的副作用闭包。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    public func also(_ f: (Base) -> Void) -> Chain<Base> {
        f(base)
        return self
    }
}

// MARK: - 入口

/// 可链入口协议：给 UIView（及一切子类）挂上 `chain()`。
///
/// 为什么走协议而不是直接在 `extension UIView` 里写 `func chain() -> Chain<Self>`：
/// Swift 编译器禁止**协变 Self** 出现在「方法结果类型」的泛型参数里
/// （`-> Chain<Self>` 直接报 "covariant 'Self' can only appear at the top level
/// of method result type"）。而协议扩展里的 `Self` 是被会议类型的具体类型，
/// 编译器放行它进泛型括号 —— 于是 `UILabel().chain()` 得到 `Chain<UILabel>`，
/// 后面只跟得到 UILabel 的方法（这是对 ZZFLEX 弱类型链的核心优化）。
public protocol Chainable {}

/// 链入口扩展：给 `UIView` 及其所有子类挂上点语法 `chain()` 入口。
public extension Chainable where Self: UIView {
    /// 点语法入口。返回 `Chain<Self>`，保住本视图的具体类型。
    ///
    /// 之后链上只跟得动该具体类型的方法。
    /// - Returns: 包装当前视图的 `Chain<Self>`，支持继续链式设置。
    @discardableResult
    @MainActor
    func chain() -> Chain<Self> {
        Chain(self)
    }
}

// 所有 UIView（及其子类）默认即 Chainable。
extension UIView: Chainable {}

// MARK: - 层级与布局基座（所有 UIView 通用）

/// 层级与布局基座扩展：所有 `UIView` 通用的链式底层方法。
public extension Chain where Base: UIView {

    /// 加入父视图层级（等价 `superview.addSubview(base)`），返回自身继续链。
    ///
    ///     let card = UIView().chain()
    ///         .backgroundColor(.systemGray6)
    ///         .added(to: self)
    ///         .cornerRadius(10)
    ///         .build()
    ///
    /// - Parameter superview: 目标父视图。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func added(to superview: UIView) -> Chain<Base> {
        superview.addSubview(base)
        return self
    }

    /// 关闭 autoresizing mask —— Auto Layout 布局前的常规第一步。
    ///
    /// 等价 `base.translatesAutoresizingMaskIntoConstraints = false`。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func autolayout() -> Chain<Base> {
        base.translatesAutoresizingMaskIntoConstraints = false
        return self
    }
}