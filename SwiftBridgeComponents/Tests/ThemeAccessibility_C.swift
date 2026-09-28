//
//  ThemeAccessibility_C.swift
//  SwiftBridgeComponentsTests
//
//  本批「主题化 + 无障碍默认」改造的回归测试（样式参考 ComponentsTests 的冒烟写法）：
//    · Rating  —— 读屏值带星数分母；adjustable 增减上报 .changed
//    · TextField —— placeholder 驱动无障碍 label
//    · OTPField —— 只暴露隐藏域一个聚焦元素（容器不抢焦点）
//    · IndexBar —— adjustable 可调档逐字母上报；换肤重放 apply 不崩
//
//  ⚠️ 这类测试直接操作私有控件（view.field 等）需要访问 internal：
//     仓库既有约定（OTPField 的 field 本来即 internal），本次按同约定放开 TextField.field。
//

import XCTest
@testable import SwiftBridgeComponents

@MainActor
final class ThemeAccessibilityCTests: XCTestCase {

    // MARK: - Rating：读屏值带星数 + adjustable 上报

    func testRatingAccessibilityValueIncludesStarCount() {
        let view = RatingBridgeView(frame: .zero)
        view.apply(RatingState(rating: 3, starCount: 5))
        // 只断言「含星数 / 含斜杠」：String(format:) 在部分区域设置里小数点可能是逗号
        XCTAssertTrue(view.accessibilityValue?.contains("5") == true,
                      "读屏值应带星数分母，实际 \(view.accessibilityValue ?? "nil")")
        XCTAssertTrue(view.accessibilityValue?.contains("/") == true,
                      "读屏值应含斜杠分隔，实际 \(view.accessibilityValue ?? "nil")")
        view.teardown()

        // 幂等：重复 apply 不崩、值不变
        view.apply(RatingState(rating: 3, starCount: 5))
        XCTAssertTrue(view.accessibilityValue?.contains("/") == true, "读屏值应含斜杠分隔")
        view.teardown()
    }

    func testRatingAccessibilityAdjustableEmitsChanged() {
        let view = RatingBridgeView(frame: .zero)
        var captured: [RatingIntent] = []
        view.onIntent = { captured.append($0) }
        view.apply(RatingState(rating: 2, starCount: 5))

        view.accessibilityIncrement()
        XCTAssertEqual(captured.count, 1, "应收到一次 .changed")
        guard case .changed(let value)? = captured.first else {
            return XCTFail("应上报 .changed(分值)，实际 \(String(describing: captured.first))")
        }
        XCTAssertEqual(value, 3, "半星步进 +1 档：2 → 3")
        view.teardown()
    }

    // MARK: - OTPField：只暴露隐藏域一个聚焦元素

    func testOTPFieldExposesOnlyHiddenField() {
        let view = OTPFieldBridgeView(frame: .zero)
        view.apply(OTPFieldState(codeLength: 4, value: ""))
        XCTAssertTrue(view.field.isAccessibilityElement, "隐藏域应作为唯一聚焦元素")
        XCTAssertEqual(view.field.accessibilityLabel, "验证码")
        XCTAssertFalse(view.isAccessibilityElement, "容器不应设为元素（会抢焦点、挡数字键盘）")
        view.teardown()
        view.teardown()
    }

    // MARK: - TextField：placeholder 驱动无障碍 label

    func testTextFieldLabelFromPlaceholder() {
        let view = TextFieldBridgeView(frame: .zero)
        view.apply(TextFieldState(text: "", placeholder: "请输入手机号"))
        XCTAssertEqual(view.field.accessibilityLabel, "请输入手机号", "占位文案应成为读屏 label")
        view.teardown()

        // 占位文案变化 → label 跟着走；重复 apply 幂等
        view.apply(TextFieldState(text: "", placeholder: "新占位"))
        XCTAssertEqual(view.field.accessibilityLabel, "新占位")
        view.teardown()
    }

    // MARK: - IndexBar：adjustable 可调档 + 换肤重染

    func testIndexBarAccessibilityAdjustableEmitsLetter() {
        let view = IndexBarBridgeView(frame: .zero)
        var captured: [IndexBarIntent] = []
        view.onIntent = { captured.append($0) }

        view.apply(IndexBarState(items: ["A", "B", "C"]))
        view.accessibilityIncrement()
        XCTAssertEqual(captured.count, 1, "应收到一次 .changed")
        guard case .changed(let item)? = captured.first else {
            return XCTFail("应上报 .changed(字母)，实际 \(String(describing: captured.first))")
        }
        XCTAssertEqual(item, "B", "从 A 上滑一档 → B")

        // 再下滑回 A：同一上报路径去重后仍应发
        view.accessibilityDecrement()
        XCTAssertEqual(captured.count, 2, "下滑一档应再上报一次")
        guard case .changed(let back)? = captured.last else {
            return XCTFail("应上报 .changed(字母)")
        }
        XCTAssertEqual(back, "A", "从 B 下滑一档 → A")
        view.teardown()
    }

    func testIndexBarThemeChangedRebuilds() {
        let original: ComponentTheme = ComponentTheme.current
        defer { ComponentTheme.current = original }

        let view = IndexBarBridgeView(frame: .zero)
        view.apply(IndexBarState(items: ["A", "B", "C"], tone: .neutral, activeTone: .primary))
        XCTAssertEqual(view.itemLabels.count, 3)

        // 换肤后重放同一份 state：themeChanged 走重染路径，不崩且 label 栈完好
        ComponentTheme.current = .brand
        view.apply(IndexBarState(items: ["A", "B", "C"], tone: .neutral, activeTone: .primary))
        XCTAssertEqual(view.itemLabels.count, 3, "主题换肤不应破坏 label 栈")

        ComponentTheme.current = .default
        view.apply(IndexBarState(items: ["A", "B", "C"]))
        XCTAssertEqual(view.itemLabels.count, 3)
        view.teardown()
    }
}