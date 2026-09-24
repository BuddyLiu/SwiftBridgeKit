//
//  LifecyclePolicy.swift
//  SwiftBridgeKit
//
//  设施四（策略部分）：生命周期对齐。
//
//  ── 核心事实 ─────────────────────────────────────────────
//  dismantleUIView 在真实工程中**不保证**被调用（视图层级被整体替换、
//  宿主提前释放等路径下可能被跳过）。因此：
//
//    ✅ 必须做的清理（移除观察者、停定时器、断 delegate）→ 放 deinit
//    ✅ 可以做的清理（停播放、断开 layer）→ 放 dismantleUIView，但要有幂等保护
//    ❌ 唯一依赖 dismantleUIView 的资源 → 一定会泄漏
//
//  ── 为什么清理要收拢到 Coordinator ─────────────────────────
//  Coordinator 与 UI 视图同生共死（由 Representable 持有），
//  把 NSObjectProtocol 观察者、Timer、KVO 全部登记在 Coordinator 上，
//  生命周期就只在一处收口，不会散落在各个业务视图里。
//

import Foundation

/// 桥视图的清理时机分类。
public enum CleanupTiming {

    /// 确定性清理：放在 Coordinator.deinit。
    /// 适用于：NotificationCenter 观察者、Timer、KVO、DispatchSource、
    ///          任何"注册了就必须有对应注销"的成对资源。
    case onDeinit

    /// 尽力清理：放在 dismantleUIView，但必须幂等。
    /// 适用于：停止播放、断开 CALayer、释放大内存缓存 ——
    ///          这些早一点做更好，但不做也不会导致永久泄漏。
    case onDismantleBestEffort
}

/// 幂等清理标记，防止「deinit 与 dismantle 都执行 → 清理跑两遍」引发崩溃。
@MainActor
public final class OneShotTeardown {

    private var didTeardown = false

    /// 创建一份全新的「只执行一次」清理标记。
    public init() {}

    /// 只会真正执行一次。
    public func run(_ work: () -> Void) {
        guard !didTeardown else { return }
        didTeardown = true
        work()
    }

    /// 是否已经执行过清理。
    public var finished: Bool { didTeardown }
}
