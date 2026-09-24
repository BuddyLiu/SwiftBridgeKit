//
//  LifecycleTests.swift
//  SwiftBridgeKit
//
//  针对「幂等清理标记・OneShotTeardown」的单测。
//
//  为什么需要它：
//    dismantleUIView 与 deinit 两条路径都可能触发清理，
//    若没有一次性保护，同样的清理会跑两遍（移除两次观察者可能直接崩溃）。
//    这里用最直接的计数断言「只执行一次」。
//

import XCTest
@testable import SwiftBridgeKit

@MainActor
final class OneShotTeardownTests: XCTestCase {

    // MARK: - 1. 重复 run 只真正执行一次

    func testRunsExactlyOnce() {
        let teardown = OneShotTeardown()
        var executeCount = 0

        teardown.run { executeCount += 1 }
        teardown.run { executeCount += 1 }
        teardown.run { executeCount += 1 }

        XCTAssertEqual(executeCount, 1, "多次 run 只能真正执行一次")
        XCTAssertTrue(teardown.finished)
    }

    // MARK: - 2. 全新实例未执行过

    func testFreshInstanceHasNotRun() {
        let teardown = OneShotTeardown()
        XCTAssertFalse(teardown.finished)
        teardown.run {}
        XCTAssertTrue(teardown.finished)
    }

    // MARK: - 3. 幂等：第二次 run 传入任何工作都不执行

    func testSecondRunIsIgnored() {
        let teardown = OneShotTeardown()
        var sideEffect = ""

        teardown.run { sideEffect += "a" }
        teardown.run { sideEffect += "b" }

        XCTAssertEqual(sideEffect, "a", "第二次 run 的工作必须被忽略")
    }
}