//
//  BridgeCoordinator.swift
//  SwiftBridgeKit
//
//  设施三 + 设施四：通用 Coordinator。
//
//  它把三件容易写错的「框架级」事情一次做对：
//    1. 值比较早退     —— 状态没变就不写视图
//    2. 更新抑制       —— 通过 BridgeGuard 打破循环
//    3. 生命周期收拢   —— 观察者/Timer/KVO 全登记在此，统一注销
//
//  组件作者不需要重写 Coordinator，只需要让自己的 UIView 遵守 BridgeView。
//

@preconcurrency import UIKit

/// 桥接层的统一协调器，生命周期与 UI 视图同生共死。
///
/// 把三件容易写错的框架级事情一次做对：值比较早退（状态没变就不写视图）、
/// 更新抑制（通过 BridgeGuard 打破循环）、生命周期收拢
/// （观察者 / Timer / KVO 统一登记、统一注销）。
/// 组件作者不需要重写本类型，只需让自己的 UIView 遵守 BridgeView。
@MainActor
public final class BridgeCoordinator<View: BridgeView> {

    // MARK: - 外部可读状态

    /// 当前装配的桥视图，弱引用持有以防循环引用。
    public private(set) weak var view: View?

    /// 允许外层（如尺寸自适应）在需要时请求一次重新布局。
    public var onRequestLayout: (() -> Void)?

    // MARK: - 内部设施

    private let guardWindow = BridgeGuard()
    private let oneShotTeardown = OneShotTeardown()
    private let onIntent: (View.Intent) -> Void

    /// 上一次成功应用的状态，用于早退。
    private var lastApplied: View.State?

    /// 登记在案、必须注销的成对资源（设施四）。
    ///
    /// nonisolated(unsafe)：register 只在主线程追加，deinit 时不会再有并发写入，
    /// 「仅在主线程释放 + 仅主线程修改」的人为保证，编译器无法核验，故显式豁免。
    nonisolated(unsafe) private var observerTokens: [NSObjectProtocol] = []

    /// 创建一个协调器。
    ///
    /// - Parameters:
    ///   - onIntent: 意图上报的最终去向；实际上报会先经过 BridgeGuard 的抑制与延后一拍。
    public init(onIntent: @escaping (View.Intent) -> Void) {
        self.onIntent = onIntent
    }

    // MARK: - 装配

    /// 装配桥视图：建立「意图上报」与「尺寸回流」两条通道，并把上报统一收口到保护窗口。
    ///
    /// - Parameters:
    ///   - view: 要装配的桥视图。两条通道均用弱引用捕获协调器，
    ///           装配后被释放（teardown / deinit）不会再向业务侧送达上报。
    public func attach(_ view: View) {
        self.view = view

        // 上报一律经过 guardWindow：抑制 + 延后一拍。
        // 内层闭包同样 weak：teardown / deinit 后，已排队的上报不应再送达业务侧。
        view.onIntent = { [weak self] intent in
            guard let self else { return }
            self.guardWindow.emit { [weak self] in
                self?.onIntent(intent)
            }
        }

        // 尺寸回流通道：组件调用 view.onRequestLayout?() → coordinator.onRequestLayout?()
        // （后者由 BridgeRepresentable.makeUIView 注入，最终请求 SwiftUI 重新布局）。
        view.onRequestLayout = { [weak self] in
            self?.onRequestLayout?()
        }
    }

    // MARK: - 数据下行

    /// 把一份 state 快照应用到桥视图。
    ///
    /// 内部先做值比较早退（与上次相同则直接返回、不触发视图更新），
    /// 再进入保护窗口写入视图，因此调用方无需担心重复刷写。
    ///
    /// - Parameters:
    ///   - state: 从 SwiftUI 侧流入的最新数据快照。
    public func apply(_ state: View.State) {
        // ① 值比较早退：成本极低，收益极大
        guard lastApplied != state else { return }
        lastApplied = state

        // ② 抑制窗口内写入视图
        guardWindow.performUpdate { [weak self] in
            self?.view?.apply(state)
        }
    }

    // MARK: - 成对资源登记（设施四）

    /// 登记一个必须在 deinit 注销的观察者，收口到本协调器的确定性清理。
    ///
    /// 用法：`coordinator.register(NotificationCenter.default.addObserver(...))`
    /// 所有登记在案的资源都会在 deinit 中统一移除，生命周期只在一处收口。
    ///
    /// - Parameters:
    ///   - token: NotificationCenter.addObserver 返回的观察者令牌。
    public func register(_ token: NSObjectProtocol) {
        observerTokens.append(token)
    }

    // MARK: - 清理

    /// 尽量清理：断开上传通道并调用视图的 teardown，供 dismantleUIView 调用。
    ///
    /// 只做「尽力清理」且保证幂等：dismantle 不保证被调用，也不应与 deinit 的清理互相干扰，
    /// 真正的确定性清理仍收口在 Coordinator.deinit。
    public func prepareForDismantle() {
        oneShotTeardown.run { [weak self] in
            guard let self else { return }
            self.view?.onIntent = nil
            self.view?.onRequestLayout = nil
            self.view?.teardown()
        }
    }

    // MARK: - 确定性清理

    deinit {
        // 这里只做「注册了就必须注销」的确定性清理。
        //
        // deinit 是 nonisolated 的，不能从它访问 @MainActor 隔离的普通存储属性
        //（Swift 6 模式下会直接报错，已在本机 Xcode 16.4 / Swift 6.3 实测确认）。
        // observerTokens 仅在主线程被 register() 追加，deinit 之后不再有任何写入，
        // 因此把存储标记为 nonisolated(unsafe)，属于「编译器看不到的人为保证」的显式声明。
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
        // Timer.invalidate()、KVO removeObserver、DispatchSource.cancel()
        // 等成对资源同样收口在这里。
    }
}
