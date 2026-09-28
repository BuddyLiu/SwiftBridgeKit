//
//  ComponentsExpansionTests.swift
//  SwiftBridgeComponentsTests
//
//  四批扩展组件（Checkbox / RadioGroup / StepIndicator / Sparkline）的验收：
//    · 交互组件（Checkbox、RadioGroup）走 fire-* 测试钩子直连点击逻辑
//      （无头模拟器不派发 UIControl target-action，见 OverlayTests 同款约定）；
//    · 绘制型组件（StepIndicator、Sparkline）用 UIGraphicsImageRenderer 强制进
//      一层真实绘制（无头环境没有系统绘制循环），断言不崩 + 读屏值；
//    · 主题化：themeChanged 强制重绘（颜色经 resolvedColor(light) 解析后比较）。
//

import XCTest
import UIKit
@testable import SwiftBridgeComponents

@MainActor
final class ComponentsExpansionTests: XCTestCase {

    /// 亮色模式 trait：把动态色解析成具体色再断言。
    private let light = UITraitCollection(userInterfaceStyle: .light)

    /// 强制走一层真实绘制：把 layer 渲染进离屏上下文（等价系统绘制回调里的 draw(_:)）。
    private func rendering(_ view: UIView) -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        return renderer.image { ctx in view.layer.render(in: ctx.cgContext) }
    }

    // MARK: - Checkbox

    /// 点复选框只上报 .tapped，不就地翻转选中态（业务回写）。
    func testCheckboxTapEmitsTapped() {
        let view = CheckboxBridgeView(frame: .zero)
        var received: [CheckboxIntent] = []
        view.onIntent = { received.append($0) }
        view.apply(CheckboxState(title: "同意条款", isSelected: false))

        view.fireTap()

        XCTAssertEqual(received.count, 1)
        guard case .tapped = received.first else {
            return XCTFail("应收到 .tapped")
        }
        view.teardown()
    }

    /// 选中态呈现 + 单元素读屏：勾选框填主题色、checkmark 显隐、label/value 随状态。
    func testCheckboxSelectionVisualAndA11y() {
        let view = CheckboxBridgeView(frame: .zero)
        view.apply(CheckboxState(title: "同意条款", isSelected: true))

        let fill = UIColor.systemBlue.resolvedColor(with: light)
        XCTAssertEqual(view.box.backgroundColor?.resolvedColor(with: light), fill, "选中时勾选框应填主题色")
        XCTAssertFalse(view.checkmark.isHidden, "选中时 checkmark 应显示")
        XCTAssertEqual(view.label.text, "同意条款")
        XCTAssertEqual(view.accessibilityLabel, "同意条款")
        XCTAssertEqual(view.accessibilityValue, "已选")
        view.teardown()

        let unselected = CheckboxBridgeView(frame: .zero)
        unselected.apply(CheckboxState(title: "同意条款", isSelected: false))
        XCTAssertTrue(unselected.checkmark.isHidden, "未选中时 checkmark 应隐藏")
        XCTAssertEqual(unselected.accessibilityValue, "未选")
        unselected.teardown()
    }

    /// 换主题：themeChanged 强制重绘勾选框底色（默认蓝 → 品牌紫）。
    func testCheckboxThemeChangedRedrawsBackground() {
        let view = CheckboxBridgeView(frame: .zero)
        view.apply(CheckboxState(title: "同意", isSelected: true, tone: .primary))
        let defaultFill = UIColor.systemBlue.resolvedColor(with: light)
        XCTAssertEqual(view.box.backgroundColor?.resolvedColor(with: light), defaultFill)

        view.theme = ComponentTheme.brand
        view.apply(CheckboxState(title: "同意", isSelected: true, tone: .primary))
        let brandFill = ComponentTheme.brand.color(for: .primary).resolvedColor(with: light)
        XCTAssertEqual(view.box.backgroundColor?.resolvedColor(with: light), brandFill)
        view.teardown()
    }

    /// 禁用态：关手势 + 整体降透明度。
    func testCheckboxDisabledDim() {
        let view = CheckboxBridgeView(frame: .zero)
        view.apply(CheckboxState(title: "同意", isSelected: false, isEnabled: false))
        XCTAssertFalse(view.isUserInteractionEnabled)
        XCTAssertEqual(view.alpha, 0.5, accuracy: 0.0001)
        view.teardown()
    }

    // MARK: - RadioGroup

    /// 选项集合 → 逐行成按钮；fire 钩子直连点按 → 上报该选项 id。
    func testRadioGroupBuildsRowsAndOptionTapEmitsChanged() {
        let view = RadioGroupBridgeView(frame: .zero)
        let options = [RadioOption(id: "a", title: "红"), RadioOption(id: "b", title: "蓝")]
        view.apply(RadioGroupState(options: options))

        XCTAssertEqual(view.optionButtons.count, 2, "两选项应渲染出两行")
        XCTAssertEqual(view.intrinsicContentSize.height, 80, accuracy: 0.0001, "行高 40 × 2 行")

        var received: [RadioGroupIntent] = []
        view.onIntent = { received.append($0) }
        view.fireOptionTap(at: 1)

        XCTAssertEqual(received.count, 1)
        guard case .changed(let id)? = received.first else {
            return XCTFail("应收到 .changed")
        }
        XCTAssertEqual(id, "b")
        view.teardown()
    }

    /// 选中态由业务回写：selectedID 变化只刷图标色与读屏 value，不重建行。
    func testRadioGroupSelectedIconAndA11yValue() {
        let view = RadioGroupBridgeView(frame: .zero)
        let options = [RadioOption(id: "a", title: "红"), RadioOption(id: "b", title: "蓝")]
        view.apply(RadioGroupState(options: options, selectedID: "a"))

        XCTAssertEqual(view.optionButtons.count, 2)
        // 首行选中（主题色圈），其余未选中（弱化圈）
        let firstIcon = view.optionButtons[0].subviews.compactMap { $0 as? UIImageView }.first
        let secondIcon = view.optionButtons[1].subviews.compactMap { $0 as? UIImageView }.first
        XCTAssertNotNil(firstIcon?.image, "选中行应有选中圈图标")
        XCTAssertNotNil(secondIcon?.image, "未选中行也应有圈图标")
        let defaultTint = UIColor.systemBlue.resolvedColor(with: light)
        XCTAssertEqual(firstIcon?.tintColor?.resolvedColor(with: light), defaultTint)
        XCTAssertEqual(secondIcon?.tintColor?.resolvedColor(with: light),
                       UIColor.tertiaryLabel.resolvedColor(with: light))
        XCTAssertEqual(view.optionButtons[0].accessibilityValue, "已选")
        XCTAssertEqual(view.optionButtons[1].accessibilityValue, "未选")
        XCTAssertEqual(view.optionButtons[0].accessibilityLabel, "红")

        // 业务回写新选中：只刷呈现，行数不变
        view.apply(RadioGroupState(options: options, selectedID: "b"))
        XCTAssertEqual(view.optionButtons.count, 2)
        XCTAssertEqual(view.optionButtons[0].accessibilityValue, "未选")
        XCTAssertEqual(view.optionButtons[1].accessibilityValue, "已选")
        view.teardown()
    }

    /// 换主题：themeChanged 强制重绘选中圈图标色（默认蓝 → 品牌紫）。
    func testRadioGroupThemeChangedRedrawsSelectedTint() {
        let view = RadioGroupBridgeView(frame: .zero)
        view.apply(RadioGroupState(options: [RadioOption(id: "a", title: "红")], selectedID: "a"))
        let icon = view.optionButtons[0].subviews.compactMap { $0 as? UIImageView }.first
        let defaultTint = UIColor.systemBlue.resolvedColor(with: light)
        XCTAssertEqual(icon?.tintColor?.resolvedColor(with: light), defaultTint)

        view.theme = ComponentTheme.brand
        view.apply(RadioGroupState(options: [RadioOption(id: "a", title: "红")], selectedID: "a"))
        let brandTint = ComponentTheme.brand.color(for: .primary).resolvedColor(with: light)
        XCTAssertEqual(icon?.tintColor?.resolvedColor(with: light), brandTint)
        view.teardown()
    }

    /// 禁用态：逐行按钮禁用 + 整体降透明度。
    func testRadioGroupDisabledDisablesRows() {
        let view = RadioGroupBridgeView(frame: .zero)
        view.apply(RadioGroupState(options: [RadioOption(id: "a", title: "红")], isEnabled: false))
        XCTAssertTrue(view.optionButtons.allSatisfy { !$0.isEnabled })
        XCTAssertEqual(view.alpha, 0.5, accuracy: 0.0001)
        view.teardown()
    }

    /// 回归：行按钮必须被 **arranged**（addArrangedSubview），不能只 addSubview ——
    /// 否则 UIStackView 不排布 → 按钮 0×0 不可点（Demo11 实测复现的 bug）。
    func testRadioGroupRowsArrangedInStack() {
        let view = RadioGroupBridgeView(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        view.apply(RadioGroupState(options: [
            RadioOption(id: "a", title: "红"),
            RadioOption(id: "b", title: "蓝"),
            RadioOption(id: "c", title: "绿"),
        ]))

        XCTAssertEqual(view.rowsStack.arrangedSubviews.count, 3,
                       "按钮应作为 arranged subview 入栈")
        XCTAssertTrue(view.rowsStack.arrangedSubviews.allSatisfy { $0 is UIButton },
                      "arranged 的应是行按钮")

        // 头无真实 layout 循环；force 一次布局后按钮应拿到非零 frame（不再 0×0）
        view.setNeedsLayout()
        view.layoutIfNeeded()
        XCTAssertTrue(view.rowsStack.arrangedSubviews.allSatisfy { $0.frame.width > 0 && $0.frame.height > 0 },
                      "arranged 后按钮应有非零尺寸，方可点击")
        view.teardown()
    }

    // MARK: - StepIndicator

    /// 契约层钳制：currentIndex 收到 0...steps.count-1；空步骤集视为 0。
    func testStepIndicatorClampsCurrentIndex() {
        let state = StepIndicatorState(steps: ["一", "二", "三"], currentIndex: 99)
        XCTAssertEqual(state.currentIndex, 2, "越上界应收尾")

        let low = StepIndicatorState(steps: ["一", "二"], currentIndex: -3)
        XCTAssertEqual(low.currentIndex, 0, "越下界应收头")

        let empty = StepIndicatorState(steps: [], currentIndex: 7)
        XCTAssertEqual(empty.currentIndex, 0, "空步骤集钳为 0")
    }

    /// 读屏值：当前步的「第 X / N 步 · 步骤名」；空集报「暂无步骤」。
    func testStepIndicatorAccessibilityValue() {
        let view = StepIndicatorBridgeView(frame: CGRect(x: 0, y: 0, width: 300, height: 56))
        view.apply(StepIndicatorState(steps: ["填写", "确认", "完成"], currentIndex: 1))
        XCTAssertEqual(view.accessibilityValue, "第 2 / 3 步 · 确认")
        view.teardown()

        let empty = StepIndicatorBridgeView(frame: CGRect(x: 0, y: 0, width: 300, height: 56))
        empty.apply(StepIndicatorState(steps: []))
        XCTAssertEqual(empty.accessibilityValue, "暂无步骤")
        empty.teardown()
    }

    /// 绘制路径真实跑一遍（含换肤重放）：不崩即过。
    func testStepIndicatorDrawsAndThemeChanged() {
        let view = StepIndicatorBridgeView(frame: CGRect(x: 0, y: 0, width: 300, height: 56))
        view.apply(StepIndicatorState(steps: ["填写", "确认", "完成"], currentIndex: 1))
        _ = rendering(view)
        // 换主题重放：themeChanged → setNeedsDisplay → 再次进绘制
        view.theme = ComponentTheme.brand
        view.apply(StepIndicatorState(steps: ["填写", "确认", "完成"], currentIndex: 1))
        _ = rendering(view)
        // apply 同快照（值相等早退）不应崩
        view.apply(StepIndicatorState(steps: ["填写", "确认", "完成"], currentIndex: 1))
        view.teardown()
    }

    /// 回归：完成段连线端点停在「当前步节点圆周」（圆心 - 半径），不直穿圆心。
    /// 之前直接用圆心坐标，线段透过半透明浅底圈透出来、与序号重叠；末步因为
    /// min(centerX, lastX - inset) 兜底碰巧正确 —— 现在中间步与末步统一走圆周。
    func testStepIndicatorSegmentEndsAtCircumference() {
        let nodeW: CGFloat = 100
        let inset: CGFloat = 10
        let marginX: CGFloat = 12

        // 中间步（当前为第 2 个，下标 1）：圆心 = 12 + 100*1.5 = 162，左圆周 = 152
        let mid = StepIndicatorGeometry.segmentEndX(step: 1, nodeW: nodeW, inset: inset, marginX: marginX)
        XCTAssertEqual(mid, 152, accuracy: 0.0001, "中间步：连线止于当前步圆左圆周")
        XCTAssertLessThan(mid, 162, "不得越过当前步圆心")

        // 末步（下标 3）：左圆周 = 12 + 100*3.5 - 10 = 352，与基线灰线端一致
        let lastEnd = StepIndicatorGeometry.segmentEndX(step: 3, nodeW: nodeW, inset: inset, marginX: marginX)
        XCTAssertEqual(lastEnd, 352, accuracy: 0.0001, "末步：连线止于末节点左圆周")
        XCTAssertLessThan(lastEnd, 362, "末步同样不越过圆心")
    }

    // MARK: - Sparkline

    /// 读屏值：数据点密度 + 最低/最高；空序列报「暂无数据」。
    func testSparklineAccessibilityValue() {
        let view = SparklineBridgeView(frame: CGRect(x: 0, y: 0, width: 200, height: 56))
        view.apply(SparklineState(points: [1, 3, 8, 2]))
        XCTAssertEqual(view.accessibilityValue, "4 个数据点 · 最低 1 · 最高 8")
        view.teardown()

        let empty = SparklineBridgeView(frame: CGRect(x: 0, y: 0, width: 200, height: 56))
        empty.apply(SparklineState(points: []))
        XCTAssertEqual(empty.accessibilityValue, "暂无数据")
        empty.teardown()
    }

    /// 绘制路径真实跑一遍（单点 / 多点 / 关填充 / 换肤）：不崩即过。
    func testSparklineDrawsAllVariants() {
        let view = SparklineBridgeView(frame: CGRect(x: 0, y: 0, width: 200, height: 56))
        view.apply(SparklineState(points: [2, 5, 3, 9, 4]))
        _ = rendering(view)

        view.apply(SparklineState(points: [4], showsFill: false))
        _ = rendering(view)

        // 全等值：spread = 0 → 水平中线，不除零
        view.apply(SparklineState(points: [3, 3, 3]))
        _ = rendering(view)

        // 换肤重放 + 同快照早退：都不崩
        view.theme = ComponentTheme.brand
        view.apply(SparklineState(points: [2, 5, 3, 9, 4]))
        _ = rendering(view)
        view.apply(SparklineState(points: [2, 5, 3, 9, 4]))
        view.teardown()
    }
}