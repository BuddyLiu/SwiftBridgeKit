//
//  BridgeCoordinatorTests.swift
//  SwiftBridgeKit
//
//  针对「通用 Coordinator」的单测。
//
//  覆盖 Facility 三 + 四最关键的语义：
//    1. 值比较早退 —— 相同 state 连续 apply，视图只写一次
//    2. 状态变化 —— 不同 state 才真正写入视图
//    3. 更新抑制 —— 视图在 apply 过程中上报的意图会被抑制（不送达业务侧）
//    4. attach —— 注入 onIntent 通道
//

import XCTest
import UIKit
@testable import SwiftBridgeKit

// MARK: - 可观测的测试视图

private final class CountingView: UIView, BridgeView {
    typealias State = EmptyState
    typealias Intent = NoIntent

    var onIntent: ((NoIntent) -> Void)?
    var onRequestLayout: (() -> Void)?
    private(set) var applyCount = 0

    func apply(_ state: EmptyState) {
        applyCount += 1
    }
}

private struct ValueState: BridgeState {
    var value: Int
}

private final class ValueView: UIView, BridgeView {
    typealias State = ValueState
    typealias Intent = NoIntent

    var onIntent: ((NoIntent) -> Void)?
    private(set) var applyCount = 0

    func apply(_ state: ValueState) {
        applyCount += 1
    }
}

/// apply 期间主动上报的视图，用于验证抑制链路。
private final class ReportingView: UIView, BridgeView {
    typealias State = EmptyState
    typealias Intent = NoIntent

    var onIntent: ((NoIntent) -> Void)?
    private(set) var applyCount = 0

    func apply(_ state: EmptyState) {
        applyCount += 1
        onIntent?(.none)   // ⚠️ 违反规范的用法：在 apply 里上报。正是抑制器要治的路径。
    }
}

// MARK: - 测试

@MainActor
final class BridgeCoordinatorTests: XCTestCase {

    // MARK: - 1. 值比较早退

    func testApplyEarlyExitsOnEqualState() {
        let coordinator = BridgeCoordinator<CountingView>(onIntent: { _ in })
        let view = CountingView()
        coordinator.attach(view)

        coordinator.apply(EmptyState())
        coordinator.apply(EmptyState())
        coordinator.apply(EmptyState())

        XCTAssertEqual(view.applyCount, 1, "相同 state 连续 apply 应只写视图一次")
    }

    // MARK: - 2. 状态变化才写视图

    func testApplyWritesOnStateChange() {
        let coordinator = BridgeCoordinator<ValueView>(onIntent: { _ in })
        let view = ValueView()
        coordinator.attach(view)

        coordinator.apply(ValueState(value: 1))
        coordinator.apply(ValueState(value: 1))   // 相等 → 跳过
        coordinator.apply(ValueState(value: 2))   // 变化 → 写入

        XCTAssertEqual(view.applyCount, 2, "只有 state 变化时才应写入视图")
    }

    // MARK: - 3. attach 注入上报通道

    func testAttachInjectsOnIntent() {
        let coordinator = BridgeCoordinator<CountingView>(onIntent: { _ in })
        let view = CountingView()
        XCTAssertNil(view.onIntent)

        coordinator.attach(view)

        XCTAssertNotNil(view.onIntent, "attach 后应注入上报通道")
    }

    // MARK: - 3.5 attach 注入尺寸回流通道

    func testAttachWiresRequestLayout() {
        let coordinator = BridgeCoordinator<CountingView>(onIntent: { _ in })
        var layoutRequests = 0
        coordinator.onRequestLayout = { layoutRequests += 1 }

        let view = CountingView()
        coordinator.attach(view)

        XCTAssertNotNil(view.onRequestLayout, "attach 后应注入回流通道")
        view.onRequestLayout?()

        XCTAssertEqual(layoutRequests, 1, "view 的布局回流通道应打通到 coordinator.onRequestLayout")
    }

    // MARK: - 4. apply 期间的上报被抑制（整条链路：视图→guard→业务）

    func testEmitDuringApplyIsSuppressed() {
        var receivedIntents = 0
        let coordinator = BridgeCoordinator<ReportingView>(onIntent: { _ in receivedIntents += 1 })
        let view = ReportingView()
        coordinator.attach(view)

        coordinator.apply(EmptyState())
        XCTAssertEqual(view.applyCount, 1, "apply 本身要执行")

        // 排空主队列，确认抑制的上报没有延迟送达
        let exp = expectation(description: "drain")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        XCTAssertEqual(receivedIntents, 0, "apply 过程中视图上报的意图必须被抑制")
    }
}