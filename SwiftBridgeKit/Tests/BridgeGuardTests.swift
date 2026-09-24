//
//  BridgeGuardTests.swift
//  SwiftBridgeKit
//
//  针对「更新抑制器」的单测骨架。
//
//  为什么优先测 BridgeGuard：
//    尺寸塌陷、手势打架是「看得见的错」；
//    循环更新是「看不见的错」—— 不报错、不崩溃，只是长期烧电掉帧。
//    先给它上测试，收益最大（见 07_决策判据与Checklist.md §7）。
//
//  ⚠️ 这里用 XCTest。若你项目已迁移 Swift Testing，
//     请替换为 @Test / #expect 写法。
//

import XCTest
@testable import SwiftBridgeKit

@MainActor
final class BridgeGuardTests: XCTestCase {

    // MARK: - 1. 更新期间的上报必须被抑制

    func testEmitIsSuppressedDuringUpdate() {
        let guardWindow = BridgeGuard()
        var emitted = 0

        guardWindow.performUpdate {
            guardWindow.emit { emitted += 1 }
        }

        // emit 内部是 async，所以这里断言「本轮同步执行中没有额外上报」
        XCTAssertEqual(emitted, 0, "更新期间的上报应被抑制")

        // 排空主队列后仍然是 0
        let exp = expectation(description: "drain")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(emitted, 0)
    }

    // MARK: - 2. 更新结束后的上报必须放行

    func testEmitPassesOutsideUpdate() {
        let guardWindow = BridgeGuard()
        var emitted = 0

        guardWindow.emit { emitted += 1 }

        let exp = expectation(description: "drain")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        XCTAssertEqual(emitted, 1, "非更新期间的上报应放行")
    }

    // MARK: - 3. 标志必须复位（防止「一次更新后永久静默」）

    func testUpdatingFlagResetsAfterUpdate() {
        let guardWindow = BridgeGuard()
        XCTAssertFalse(guardWindow.updating)

        guardWindow.performUpdate { }

        XCTAssertFalse(guardWindow.updating, "performUpdate 结束后必须复位")
    }

    // MARK: - 4. 嵌套更新也不能把标志焊死

    func testNestedUpdateStillResets() {
        let guardWindow = BridgeGuard()

        guardWindow.performUpdate {
            guardWindow.performUpdate { }
        }

        XCTAssertFalse(guardWindow.updating, "嵌套后仍必须复位（当前实现为深度计数式）")
    }

    // MARK: - 5. 嵌套更新内层结束后，外层窗口的抑制不能提前失效

    func testNestedUpdateStillSuppressesWithinOuterWindow() {
        let guardWindow = BridgeGuard()
        var emitted = 0

        guardWindow.performUpdate {
            // 内层先结束（结束时不代表外层也结束）
            guardWindow.performUpdate { }

            // 此刻仍在外层抑制窗口内，上报必须继续被抑制
            guardWindow.emit { emitted += 1 }
        }

        // 排空主队列，确保真没有被延迟送达
        let exp = expectation(description: "drain")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        // ⚠️ 回归防护：布尔式实现这里会漏出一个上报（内层 defer 提前复位外层标志）。
        XCTAssertEqual(emitted, 0, "内层结束后，外层窗口内上报仍应被抑制")
    }
}

// MARK: - 早退逻辑单测建议（需组件侧配合）

/*
 「值比较早退」的验证建议放到接入组件后做，因为需要观察 apply 的实际调用次数：

    final class CountingView: UIView, BridgeView {
        var onIntent: ((NoIntent) -> Void)?
        var applyCount = 0
        func apply(_ state: EmptyState) { applyCount += 1 }
    }

 断言：
    - 连续两次 apply 相同的 state → applyCount 只涨 1
    - 视图静置时 CPU 接近空载（这是循环更新的照妖镜）
*/
