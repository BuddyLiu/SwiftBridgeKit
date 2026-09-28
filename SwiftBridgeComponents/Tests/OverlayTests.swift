//
//  OverlayTests.swift
//  SwiftBridgeComponentsTests
//
//  弹层设施（目标窗注入 presenter + 容器 + Dialog/ActionSheet/BottomSheet）的测试。
//
//  全部使用 animationDuration = 0（即时到终态，无异步动画依赖）；
//  框架测试约定：present → 断言 → dismiss（幂等），单例 OverlayManager 跨用例复用。
//

import XCTest
@testable import SwiftBridgeComponents

@MainActor
final class OverlayTests: XCTestCase {

    /// 零时长配置：动画即时到达终态，便于断言。
    private func zeroDurationOptions(placement: OverlayPlacement = .center) -> OverlayPresentation {
        OverlayPresentation(placement: placement, animationDuration: 0)
    }

    /// 每次用例前清空残留弹层（单例共享，防串味）。
    override func setUp() {
        super.setUp()
        OverlayManager.shared.dismiss()
    }

    // MARK: - 容器装配

    /// present 后：窗口 + container/dim/card + 内容视图在层级里，dim 淡到终态。
    func testPresentCreatesWindowAndHierarchy() {
        let view = DialogBridgeView()
        OverlayManager.shared.present(view: view, presentation: zeroDurationOptions())

        XCTAssertTrue(OverlayManager.shared.isPresenting)
        XCTAssertTrue(OverlayManager.shared.currentContent === view)

        guard let container = OverlayManager.shared.container else {
            return XCTFail("present 后应有容器视图")
        }
        guard let window = container.window else {
            return XCTFail("容器应挂进宿主窗口")
        }
        XCTAssertEqual(window.windowLevel, .alert + 1, "弹层窗口级别应高于 alert")
        XCTAssertTrue(container.dimView.isDescendant(of: container))
        XCTAssertTrue(container.cardView.isDescendant(of: container))
        XCTAssertTrue(view.isDescendant(of: container.cardView), "内容视图应铺进卡片位")
        XCTAssertEqual(container.dimView.alpha, 0.42, accuracy: 0.0001, "entry 动画（0 时长）应已到终态")

        OverlayManager.shared.dismiss()
    }

    /// presenter 不改内容：present 后对同一视图 apply 状态，组件照常渲染。
    func testPresentAppliesState() {
        let view = BottomSheetBridgeView()
        OverlayManager.shared.present(view: view,
                                      presentation: zeroDurationOptions(placement: .bottom))

        view.apply(BottomSheetState(rows: [
            .init(id: "a", title: "红"),
            .init(id: "b", title: "蓝", detail: "推荐"),
        ]))

        XCTAssertTrue(OverlayManager.shared.currentContent === view)
        let buttons = view.rowsStack.arrangedSubviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(buttons.count, 2, "两行应渲染出两个按钮")

        OverlayManager.shared.dismiss()
    }

    /// 幂等：两个方向（显示中重复 dismiss / 已收起再 dismiss）都不崩、不重复收容。
    func testDismissIsIdempotent() {
        let view = DialogBridgeView()
        OverlayManager.shared.present(view: view, presentation: zeroDurationOptions())

        OverlayManager.shared.dismiss()
        XCTAssertFalse(OverlayManager.shared.isPresenting)

        OverlayManager.shared.dismiss()
        OverlayManager.shared.dismiss()
        XCTAssertFalse(OverlayManager.shared.isPresenting)
    }

    /// LIFO 替换：新弹层进来先无动画收掉旧弹层（内容 teardown 断开通道）。
    func testLIFOReplace() {
        let first = DialogBridgeView()
        first.onIntent = { _ in }
        OverlayManager.shared.present(view: first, presentation: zeroDurationOptions())

        let second = ActionSheetBridgeView()
        OverlayManager.shared.present(view: second,
                                      presentation: zeroDurationOptions(placement: .bottom))

        XCTAssertTrue(OverlayManager.shared.currentContent === second, "单弹层 LIFO：后弹覆盖先弹")
        XCTAssertNil(first.onIntent, "被替换的旧弹层应已 teardown（断开上报通道）")

        OverlayManager.shared.dismiss()
    }

    /// 0 时长动画：present 后 immediately 到达终态，供无异步的环境断言。
    func testAnimationZeroDurationReachesFinalState() {
        let view = DialogBridgeView()
        OverlayManager.shared.present(view: view, presentation: zeroDurationOptions())

        guard let container = OverlayManager.shared.container else {
            return XCTFail("应有容器")
        }
        XCTAssertEqual(container.cardView.alpha, 1, accuracy: 0.0001)
        XCTAssertEqual(container.dimView.alpha, 0.42, accuracy: 0.0001)
        XCTAssertTrue(container.cardView.transform == .identity)

        OverlayManager.shared.dismiss()
    }

    // MARK: - 三个弹层组件的交互语义

    /// Dialog：点动作 → 先抛 .tapped 再请求关闭。
    func testDialogActionTapEmitsAndRequestsClose() {
        let view = DialogBridgeView()
        var received: [DialogIntent] = []
        var closeRequested = 0
        view.onIntent = { received.append($0) }
        view.onRequestDismiss = { closeRequested += 1 }

        let action = DialogAction(id: "ok", title: "确定", style: .primary)
        view.apply(DialogState(title: "确认", actions: [action]))

        let buttons = view.actionsStack.arrangedSubviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(buttons.count, 1)
        view.fireActionTap(at: 0)

        XCTAssertEqual(received.count, 1)
        guard case .tapped(let tapped)? = received.first else {
            return XCTFail("应收到 .tapped")
        }
        XCTAssertEqual(tapped.id, "ok")
        XCTAssertEqual(closeRequested, 1, "点动作应请求关闭")
    }

    /// ActionSheet：点取消 → 抛 .tapped(该取消项) 并请求关闭。
    func testActionSheetCancelIsClose() {
        let view = ActionSheetBridgeView()
        var received: [ActionSheetIntent] = []
        var closeRequested = 0
        view.onIntent = { received.append($0) }
        view.onRequestDismiss = { closeRequested += 1 }

        let cancel = ActionSheetItem(id: "cancel", title: "取消", cancel: true)
        view.apply(ActionSheetState(title: "导出", items: [cancel]))

        view.fireCancelTap()

        XCTAssertEqual(received.count, 1)
        guard case .tapped(let tapped)? = received.first else {
            return XCTFail("应收到 .tapped")
        }
        XCTAssertEqual(tapped.id, "cancel")
        XCTAssertEqual(closeRequested, 1, "点取消应请求关闭")
    }

    /// BottomSheet：行被点只上报 .changed 不自动关；取消才上报 .canceled 并请求关闭。
    func testBottomSheetChangedDoesNotAutoClose() {
        let view = BottomSheetBridgeView()
        var received: [BottomSheetIntent] = []
        var closeRequested = 0
        view.onIntent = { received.append($0) }
        view.onRequestDismiss = { closeRequested += 1 }

        view.apply(BottomSheetState(rows: [
            .init(id: "red", title: "红", selected: true),
        ]))

        let buttons = view.rowsStack.arrangedSubviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(buttons.count, 1, "取消区也渲染为行按钮? 取消区独立，不应进 rowsStack")

        // 行被点：只上报，不自动关
        view.fireRowTap(at: 0)
        XCTAssertEqual(received.count, 1)
        guard case .changed(let id)? = received.first else {
            return XCTFail("应收到 .changed")
        }
        XCTAssertEqual(id, "red")
        XCTAssertEqual(closeRequested, 0, ".changed 不应触发请求关闭，业务决定收起时机")

        // 取消：上报 .canceled 并请求关闭
        view.fireCancelTap()
        XCTAssertEqual(received.count, 2)
        guard case .canceled = received[1] else {
            return XCTFail("应收到 .canceled")
        }
        XCTAssertEqual(closeRequested, 1, "取消才请求关闭")
    }

    // MARK: - 容器手势

    /// 点蒙层（dismissOnTapDim）→ 容器请求关闭 → 管理器收掉弹层。
    func testDimTapRequestsDismiss() {
        let view = DialogBridgeView()
        OverlayManager.shared.present(view: view, presentation: zeroDurationOptions())

        guard let container = OverlayManager.shared.container else {
            return XCTFail("应有容器")
        }
        container.fireDimTap()

        XCTAssertFalse(OverlayManager.shared.isPresenting, "点蒙层应请求并完成关闭")

        // 反向：dismissOnTapDim = false 时点蒙层不应关
        OverlayManager.shared.present(
            view: DialogBridgeView(),
            presentation: OverlayPresentation(dismissOnTapDim: false, animationDuration: 0))
        OverlayManager.shared.container?.fireDimTap()
        XCTAssertTrue(OverlayManager.shared.isPresenting, "关闭点蒙层关时点它不应关")

        OverlayManager.shared.dismiss()
    }
}