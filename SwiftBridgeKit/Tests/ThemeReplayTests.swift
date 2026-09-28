//
//  ThemeReplayTests.swift
//  SwiftBridgeKit
//
//  针对「主题可注入」在核心层的单测（设施：主题可注入）。
//
//  覆盖 BridgeCoordinator 双子元组早退（state + theme）的关键语义：
//    1. 同 state + 同 theme 早退；仅 theme 变化也重放（组件靠它强刷颜色）
//    2. apply(state, theme:) 重放时把 theme 写进桥视图
//    3. theme 在 nil ↔ 值 之间切换都算变化、都重放
//    4. 向后兼容：旧签名 apply(state) 语义不变
//    5. 跨类型 theme 永不相等（AnyHashable 类型擦除的边界）
//

import XCTest
import UIKit
@testable import SwiftBridgeKit

// MARK: - 测试用值主题（不同类型但可构造「值相同」的组合）

private struct ThemeA: BridgeTheme { var value: Int }
private struct ThemeB: BridgeTheme { var value: Int }

// MARK: - 可观测主题注入的测试视图

private final class ThemeTrackingView: UIView, BridgeView {
    typealias State = EmptyState
    typealias Intent = NoIntent

    var onIntent: ((NoIntent) -> Void)?
    /// 具名存储属性：覆盖协议默认空实现（默认 set 丢弃写入，必须自己存才验得到注入）。
    var theme: (any BridgeTheme)?

    private(set) var applyCount = 0
    private(set) var injectedTheme: (any BridgeTheme)?

    func apply(_ state: EmptyState) {
        applyCount += 1
        injectedTheme = theme
    }
}

// MARK: - 测试

@MainActor
final class ThemeReplayTests: XCTestCase {

    /// 双子元组早退：同 state 下仅 theme 变化也要重放 apply。
    func testApplyEarlyExitIncludesTheme() {
        let coordinator = BridgeCoordinator<ThemeTrackingView>(onIntent: { _ in })
        let view = ThemeTrackingView()
        coordinator.attach(view)

        coordinator.apply(EmptyState(), theme: ThemeA(value: 1))
        coordinator.apply(EmptyState(), theme: ThemeA(value: 1))   // 同 state 同 theme → 跳过
        coordinator.apply(EmptyState(), theme: ThemeA(value: 2))   // 同 state 异 theme → 重放

        XCTAssertEqual(view.applyCount, 2, "同 state 下仅 theme 变化也应重放 apply，组件才能强刷颜色")
    }

    /// 重放时会顺便把 theme 注入桥视图，组件 apply 内经 resolvedTheme() 取色。
    func testApplySetsViewThemeOnReplay() {
        let coordinator = BridgeCoordinator<ThemeTrackingView>(onIntent: { _ in })
        let view = ThemeTrackingView()
        coordinator.attach(view)

        coordinator.apply(EmptyState(), theme: ThemeA(value: 7))

        XCTAssertEqual(view.applyCount, 1)
        XCTAssertEqual(view.injectedTheme as? ThemeA, ThemeA(value: 7), "重放时应把 theme 写进桥视图")
    }

    /// theme 从无到有、再从有到无，两个方向都算变化、都要重放。
    func testThemeNilVsValueTriggersReapply() {
        let coordinator = BridgeCoordinator<ThemeTrackingView>(onIntent: { _ in })
        let view = ThemeTrackingView()
        coordinator.attach(view)

        coordinator.apply(EmptyState())                            // 1: theme = nil
        coordinator.apply(EmptyState(), theme: ThemeA(value: 1))   // 2: nil → 值
        coordinator.apply(EmptyState(), theme: ThemeA(value: 1))   // 跳过
        coordinator.apply(EmptyState())                            // 3: 值 → nil

        XCTAssertEqual(view.applyCount, 3, "nil↔值 切换都算 theme 变化")
        XCTAssertNil(view.injectedTheme, "最后一次注入应为 nil")
    }

    /// 向后兼容：既有调用 apply(state) 不传 theme，语义保持不变。
    func testApplySignatureBackwardCompatible() {
        let coordinator = BridgeCoordinator<ThemeTrackingView>(onIntent: { _ in })
        let view = ThemeTrackingView()
        coordinator.attach(view)

        coordinator.apply(EmptyState())
        coordinator.apply(EmptyState())

        XCTAssertEqual(view.applyCount, 1, "旧签名 apply(state) 的同 state 早退不变")
        XCTAssertNil(view.injectedTheme)
    }

    /// 跨类型 theme 永不相等：即使值相同、hash 相同，AnyHashable 类型擦除也判不等。
    func testThemeEqualityAcrossTypesFalse() {
        let coordinator = BridgeCoordinator<ThemeTrackingView>(onIntent: { _ in })
        let view = ThemeTrackingView()
        coordinator.attach(view)

        coordinator.apply(EmptyState(), theme: ThemeA(value: 1))
        coordinator.apply(EmptyState(), theme: ThemeB(value: 1))

        XCTAssertEqual(view.applyCount, 2, "不同类型 theme 必须视为不相等，触发重放")
    }
}