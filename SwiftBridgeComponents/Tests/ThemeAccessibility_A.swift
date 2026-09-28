//
//  ThemeAccessibility_A.swift
//  SwiftBridgeComponentsTests
//
//  批次 A 组件（Button / Switch / Slider / Stepper / Segmented / ProgressBar /
//  ActivityIndicator / PageControl / DatePicker / PickerWheel）「主题化 + 无障碍默认」验收：
//    · 每个桥视图可注入 per-bridge theme，apply 时 themeChanged 强制颜色重绘
//    · 原生控件补中文 accessibilityLabel；合成容器收敛为单元素 + 派生 accessibilityValue
//  颜色断言统一经 `resolvedColor(with: light)` 落成具体色后再比，避免依赖系统语义色精确 RGB。
//

import XCTest
@testable import SwiftBridgeComponents

@MainActor
final class ThemeAccessibilityATests: XCTestCase {

    /// 亮色模式 trait：把动态色解析成具体色再断言。
    private let light = UITraitCollection(userInterfaceStyle: .light)

    // MARK: - Switch（原生控件 label + 换主题重绘）

    func testSwitchBridgeViewExposesLabel() {
        let view = SwitchBridgeView(frame: .zero)
        XCTAssertEqual(view.sw.accessibilityLabel, "开关")
        view.apply(SwitchState(isOn: true, tone: .success))
        XCTAssertEqual(view.sw.accessibilityLabel, "开关", "apply 不应冲掉无障碍 label")
        view.teardown()
    }

    func testSwitchBridgeViewRedrawsOnThemeChange() {
        let view = SwitchBridgeView(frame: .zero)
        // 首帧：默认主题 primary = 系统蓝
        view.apply(SwitchState(isOn: true, tone: .primary))
        let defaultLight = UIColor.systemBlue.resolvedColor(with: light)
        XCTAssertEqual(view.sw.onTintColor?.resolvedColor(with: light), defaultLight)
        // 换主题：primary 变品牌紫，themeChanged 强制重绘
        view.theme = ComponentTheme.brand
        view.apply(SwitchState(isOn: true, tone: .primary))
        let brandLight = ComponentTheme.brand.color(for: .primary).resolvedColor(with: light)
        XCTAssertEqual(view.sw.onTintColor?.resolvedColor(with: light), brandLight)
        view.teardown()
    }

    // MARK: - Slider / Stepper / DatePicker（原生控件 label）

    func testSliderBridgeViewExposesLabel() {
        let view = SliderBridgeView(frame: .zero)
        XCTAssertEqual(view.sl.accessibilityLabel, "滑块")
        view.apply(SliderState(value: 0.5))
        XCTAssertEqual(view.sl.accessibilityLabel, "滑块", "apply 不应冲掉无障碍 label")
        view.teardown()
    }

    func testStepperBridgeViewExposesLabel() {
        let view = StepperBridgeView(frame: .zero)
        XCTAssertEqual(view.stepper.accessibilityLabel, "步进器")
        view.apply(StepperState(value: 3, tone: .success))
        view.teardown()
    }

    func testDatePickerBridgeViewExposesLabel() {
        let view = DatePickerBridgeView(frame: .zero)
        XCTAssertEqual(view.picker.accessibilityLabel, "日期选择")
        view.apply(DatePickerState())
        view.teardown()
    }

    // MARK: - ProgressBar（合成容器单元素 + 派生 value）

    func testProgressBarBridgeViewSingleElementWithValue() {
        let view = ProgressBarBridgeView(frame: .zero)
        XCTAssertTrue(view.isAccessibilityElement, "进度条应收敛为单元素")
        XCTAssertEqual(view.accessibilityLabel, "进度")
        // 确定态：百分比
        view.apply(ProgressBarState(progress: 0.5))
        view.layoutIfNeeded()
        XCTAssertEqual(view.accessibilityValue, "50%")
        // 转圈态：加载中
        view.apply(ProgressBarState(progress: 0.5, isIndeterminate: true))
        XCTAssertEqual(view.accessibilityValue, "加载中")
        // 回到确定态：随 progress 更新
        view.apply(ProgressBarState(progress: 0.25))
        XCTAssertEqual(view.accessibilityValue, "25%")
        view.teardown()
    }

    // MARK: - ActivityIndicator（合成容器单元素）

    func testActivityIndicatorBridgeViewSingleElementLabel() {
        let view = ActivityIndicatorBridgeView(frame: .zero)
        XCTAssertTrue(view.isAccessibilityElement, "加载指示器应收敛为单元素")
        XCTAssertEqual(view.accessibilityLabel, "加载中")
        view.apply(ActivityIndicatorState(isAnimating: true, size: .large))
        XCTAssertTrue(view.isAccessibilityElement, "apply 不应破坏单元素语义")
        view.teardown()
    }

    // MARK: - PageControl（原生控件 label）

    func testPageControlBridgeViewExposesLabel() {
        let view = PageControlBridgeView(frame: .zero)
        XCTAssertEqual(view.pageControl.accessibilityLabel, "页码")
        view.apply(PageControlState(pageCount: 5, currentPage: 3))
        XCTAssertEqual(view.pageControl.numberOfPages, 5)
        XCTAssertEqual(view.pageControl.accessibilityLabel, "页码", "apply 不应冲掉无障碍 label")
        view.teardown()
    }

    // MARK: - Button（换主题重绘：theme 存储 + resolvedTheme 生效）

    func testButtonBridgeViewThemeOverrideRedraws() {
        let view = ButtonBridgeView(frame: .zero)
        let state = ButtonState(title: "确定", style: .primary, size: .regular)
        // 首帧：默认主题落盘
        view.apply(state)
        // 换上品牌主题：per-bridge override 应被存储，resolvedTheme() 生效
        view.theme = ComponentTheme.brand
        view.apply(state)
        // 同 state 再 apply：themeChanged 已重绘过，不崩
        view.apply(state)

        let storedTheme = view.theme as? ComponentTheme
        XCTAssertNotNil(storedTheme, "每桥主题覆盖应被存储（默认空实现会被存储属性取代）")
        XCTAssertEqual(storedTheme, .some(ComponentTheme.brand), "存下来的应是品牌主题")
        view.teardown()
    }
}