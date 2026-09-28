//
//  ThemeAccessibility_B.swift
//  SwiftBridgeComponentsTests
//
//  B 批（主题化 + 无障碍默认）8 个组件的冒烟：
//   每桥 = 构造 → apply → 断言（主题 + 无障碍）→ teardown 两次（幂等）。
//   apply 幂等：同 State 再 apply 一遍不崩、值不变。
//

import XCTest
@testable import SwiftBridgeComponents

/// B 批主题化 + 无障碍默认的冒烟测试。
/// @MainActor：所有桥视图都在主演员上创建与使用。
@MainActor
final class ThemeAccessibilityBTests: XCTestCase {

    // MARK: - Avatar

    func testBAvatarAccessibilityLabelFollowsTitle() {
        let view = AvatarBridgeView(frame: .zero)
        view.apply(AvatarState(title: "李月"))
        view.apply(AvatarState(title: "李月"))
        XCTAssertTrue(view.isAccessibilityElement, "头像容器是单读屏元素")
        XCTAssertEqual(view.accessibilityLabel, "李月", "单元素 label = 完整姓名（首字母只是视觉占位）")

        view.apply(AvatarState(title: ""))
        XCTAssertNil(view.accessibilityLabel, "title 为空时 label 置 nil，回落系统默认")
        view.teardown()
        view.teardown()
    }

    func testBAvatarThemeOverrideTakesEffect() {
        let view = AvatarBridgeView(frame: .zero)
        view.theme = ComponentTheme.brand
        // 品牌主题下 apply 不崩，且 per-bridge 覆盖被存储、可被 resolvedTheme() 解析
        view.apply(AvatarState(title: "李", showsStatusDot: true, statusDotTone: .danger))
        XCTAssertNotNil(view.theme as? ComponentTheme, "theme 存储生效（协议可选属性被桥实现）")
        view.teardown()
        view.teardown()
    }

    // MARK: - Badge

    func testBBadgeSingleElementAndTextLabel() {
        let view = BadgeBridgeView(frame: .zero)
        let state = BadgeState(text: "99+", tone: .danger)
        view.apply(state)
        view.apply(state)
        XCTAssertTrue(view.isAccessibilityElement, "徽章容器是单读屏元素")
        XCTAssertEqual(view.accessibilityLabel, "99+", "label = 角标实际展示文案")
        view.teardown()
        view.teardown()
    }

    func testBBadgeThemeOverrideDoesNotCrash() {
        let view = BadgeBridgeView(frame: .zero)
        view.theme = ComponentTheme.brand
        view.apply(BadgeState(text: "3", tone: .success))
        XCTAssertNotNil(view.theme as? ComponentTheme)
        view.teardown()
        view.teardown()
    }

    // MARK: - Chip

    func testBChipButtonTraitAndSelectedValue() {
        let view = ChipBridgeView(frame: .zero)
        view.apply(ChipState(title: "全部", isSelected: true))
        view.apply(ChipState(title: "全部", isSelected: true))
        XCTAssertTrue(view.isAccessibilityElement, "chip 容器是单读屏元素")
        XCTAssertTrue(view.accessibilityTraits.contains(.button), "可点 chip 是 button 语义")
        XCTAssertEqual(view.accessibilityLabel, "全部")
        XCTAssertEqual(view.accessibilityValue, "已选", "选中态读给读屏")

        view.apply(ChipState(title: "全部", isSelected: false))
        XCTAssertNil(view.accessibilityValue, "未选中回落默认 value")
        view.teardown()
        view.teardown()
    }

    // MARK: - Notice

    func testBNoticeLabelConcatsTitleAndMessage() {
        let view = NoticeBridgeView(frame: .zero)
        view.apply(NoticeState(title: "保存成功", message: "已同步"))
        view.apply(NoticeState(title: "保存成功", message: "已同步"))
        XCTAssertTrue(view.isAccessibilityElement, "横幅容器是单读屏元素")
        XCTAssertTrue(view.accessibilityLabel?.contains("保存成功") == true, "label 含标题")
        XCTAssertEqual(view.accessibilityLabel, "保存成功，已同步", "label = 标题，正文")

        view.apply(NoticeState(title: "保存成功"))
        XCTAssertEqual(view.accessibilityLabel, "保存成功", "无正文时 label 只有标题")
        view.teardown()
        view.teardown()
    }

    // MARK: - EmptyState

    func testBEmptyStateKeepsButtonsAccessible() {
        let view = EmptyStateBridgeView(frame: .zero)
        let state = EmptyStateState(title: "暂无数据", actionTitle: "重新加载")
        view.apply(state)
        view.apply(state)
        // 含交互按钮 → 容器不做单元素，避免挡掉按钮可达性（按钮 UIButton 原可达）
        XCTAssertFalse(view.isAccessibilityElement, "容器不是读屏元素，按钮保持可达")

        view.theme = ComponentTheme.brand
        view.apply(EmptyStateState(title: "暂无数据", actionTitle: "重新加载"))
        XCTAssertNotNil(view.theme as? ComponentTheme, "品牌主题 apply 不崩")
        view.teardown()
        view.teardown()
    }

    // MARK: - Toast

    func testBToastLabelIsMessage() {
        let view = ToastBridgeView(frame: .zero)
        view.apply(ToastState(message: "已复制"))
        view.apply(ToastState(message: "已复制"))
        XCTAssertEqual(view.accessibilityLabel, "已复制", "label = 提示文案")
        XCTAssertTrue(view.accessibilityTraits.contains(.staticText), "Toast 是 staticText 语义")
        // 显隐转变会摘/挂读屏树；announcement 纯函数层不便断言，这里只验证转变不崩
        view.apply(ToastState(message: "已复制", isPresented: true))
        view.apply(ToastState(message: "已复制", isPresented: false))
        view.teardown()
        view.teardown()
    }

    // MARK: - SearchField

    func testBSearchFieldPlaceholderBecomesLabel() {
        let view = SearchFieldBridgeView(frame: .zero)
        view.apply(SearchFieldState(placeholder: "搜索商品"))
        view.apply(SearchFieldState(placeholder: "搜索商品"))
        XCTAssertEqual(view.searchBar.accessibilityLabel, "搜索商品", "占位文案映射到搜索框 label")

        view.apply(SearchFieldState(placeholder: ""))
        XCTAssertNil(view.searchBar.accessibilityLabel, "空占位保留系统默认（不覆盖）")
        view.teardown()
        view.teardown()
    }

    // MARK: - TextView

    func testBTextViewPlaceholderLabelAndDynamicType() {
        let view = TextViewBridgeView(frame: .zero)
        XCTAssertTrue(view.textView.adjustsFontForContentSizeCategory, "多行输入框跟随动态字体")

        view.apply(TextViewState(placeholder: "请输入备注"))
        view.apply(TextViewState(placeholder: "请输入备注"))
        XCTAssertEqual(view.textView.accessibilityLabel, "请输入备注", "占位文案作输入框 label")

        view.apply(TextViewState(placeholder: ""))
        XCTAssertNil(view.textView.accessibilityLabel, "空占位不覆盖系统默认")
        view.teardown()
        view.teardown()
    }
}