//
//  RatioResolverTests.swift
//  SwiftBridgeKit
//
//  针对「异步比例协调器・RatioResolver」的单测。
//
//  覆盖三条最容易写错的路径：
//    1. 相同比例必须早退 —— 否则「上报 → 布局 → 再上报」退化成循环路径 C
//    2. 非法值（0 / 负 / inf / nan）必须忽略，且不破坏上一次有效值
//    3. 重置要清掉回调，避免反后残留触发意外布局
//

import XCTest
@testable import SwiftBridgeKit

@MainActor
final class RatioResolverTests: XCTestCase {

    private func drainMainQueue() {
        let exp = expectation(description: "drain")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1)
    }

    // MARK: - 1. 首次 resolve 会请求一次布局

    func testResolveTriggersOneLayoutRequest() {
        let resolver = RatioResolver()
        var layoutRequests = 0
        resolver.onRequestLayout = { layoutRequests += 1 }

        resolver.resolve(2.0)
        drainMainQueue()

        XCTAssertEqual(layoutRequests, 1, "比例首次就绪应请求一次布局")
        XCTAssertEqual(resolver.ratio, 2.0)
    }

    // MARK: - 2. 相同比例早退（防循环路径 C）

    func testSameRatioDoesNotReRequestLayout() {
        let resolver = RatioResolver()
        var layoutRequests = 0
        resolver.onRequestLayout = { layoutRequests += 1 }

        resolver.resolve(2.0)
        drainMainQueue()
        resolver.resolve(2.0)
        drainMainQueue()
        resolver.resolve(2.0)
        drainMainQueue()

        XCTAssertEqual(layoutRequests, 1, "相同比例不应重复请求布局")
    }

    // MARK: - 3. 非法值被忽略且不破坏上次有效值

    func testInvalidValuesAreIgnored() {
        let resolver = RatioResolver()
        XCTAssertNil(resolver.ratio)

        resolver.resolve(0)
        resolver.resolve(-1)
        resolver.resolve(.infinity)
        resolver.resolve(.nan)
        XCTAssertNil(resolver.ratio, "非法值一律忽略，保持未知状态")

        resolver.resolve(2.0)
        resolver.resolve(0)
        resolver.resolve(.nan)
        XCTAssertEqual(resolver.ratio, 2.0, "非法值不能覆盖上一次有效值")
    }

    // MARK: - 4. reset 清掉比例与回调

    func testResetClearsRatioAndCallback() {
        let resolver = RatioResolver()
        resolver.resolve(2.0)
        drainMainQueue()
        XCTAssertNotNil(resolver.ratio)

        resolver.reset()

        XCTAssertNil(resolver.ratio)
        XCTAssertNil(resolver.onRequestLayout)
    }
}