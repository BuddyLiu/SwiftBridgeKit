//
//  ComponentsTests.swift
//  SwiftBridgeComponentsTests
//
//  契约层与样式映射的测试：
//    · 各 State 默认值
//    · Equatable 早退语义（尤其 Avatar 的 UIImage 同一性）
//    · UIKit 样式映射 spot-check
//

import XCTest
@testable import SwiftBridgeComponents

final class ComponentsTests: XCTestCase {

    // MARK: - 契约层默认值

    func testButtonStateDefaults() {
        let s = ButtonState(title: "确定")
        XCTAssertEqual(s.style, .primary)
        XCTAssertEqual(s.size, .regular)
        XCTAssertNil(s.icon)
        XCTAssertEqual(s.iconPosition, .leading, "图标默认在文字左侧")
        XCTAssertTrue(s.isEnabled)
        XCTAssertFalse(s.isLoading)
        XCTAssertNil(s.loadingTitle)
    }

    func testBadgeStateDefaults() {
        let s = BadgeState(text: "99+")
        XCTAssertEqual(s.tone, .primary)
        XCTAssertEqual(s.shape, .round)
        XCTAssertFalse(s.showsDot)
        XCTAssertNil(s.maxValue, "默认不截断")
    }

    func testTextFieldStateDefaults() {
        let s = TextFieldState(text: "")
        XCTAssertEqual(s.placeholder, "")
        XCTAssertEqual(s.placeholderTone, .neutral)
        XCTAssertTrue(s.showsClearButton)
        XCTAssertEqual(s.keyboard, .standard)
        XCTAssertNil(s.leadingIcon)
        XCTAssertEqual(s.border, .roundedRect)
        XCTAssertFalse(s.isSecure, "默认不开密码")
        XCTAssertNil(s.maxLength, "默认不限长")
    }

    func testAvatarStateDefaults() {
        let s = AvatarState(title: "李")
        XCTAssertNil(s.image)
        XCTAssertEqual(s.shape, .circular)
        XCTAssertEqual(s.dimension, 40)
        XCTAssertEqual(s.borderWidth, 0)
        XCTAssertNil(s.borderTone)
        XCTAssertFalse(s.showsStatusDot, "默认无在线状态点")
        XCTAssertEqual(s.statusDotTone, .success)
    }

    func testRatingStateDefaults() {
        let s = RatingState(rating: 2.5)
        XCTAssertEqual(s.starCount, 5)
        XCTAssertTrue(s.isEnabled)
        XCTAssertEqual(s.starTone, .system)
        XCTAssertTrue(s.allowsHalfSteps)
    }

    func testRatingStateClamps() {
        XCTAssertEqual(RatingState(rating: 7, starCount: 3).rating, 3, "超上限收进 starCount")
        XCTAssertEqual(RatingState(rating: -1, starCount: 5).rating, 0, "低于 0 收进 0")
        XCTAssertEqual(RatingState(rating: 2.5, starCount: 5).rating, 2.5, "界内原样")
        XCTAssertEqual(RatingState(rating: 3, starCount: 0).starCount, 1, "starCount 最少 1")
        XCTAssertEqual(RatingState(rating: 9, starCount: 0).rating, 1, "starCount 钳到 1 后 rating 也收进 [0,1]")
    }

    func testRatingGeometrySnap() {
        XCTAssertEqual(RatingGeometry.snapped(raw: 2.4, starCount: 5, allowsHalfSteps: true), 2.5)
        XCTAssertEqual(RatingGeometry.snapped(raw: 2.6, starCount: 5, allowsHalfSteps: true), 2.5)
        XCTAssertEqual(RatingGeometry.snapped(raw: 2.9, starCount: 5, allowsHalfSteps: true), 3)
        XCTAssertEqual(RatingGeometry.snapped(raw: 2.4, starCount: 5, allowsHalfSteps: false), 2)
        XCTAssertEqual(RatingGeometry.snapped(raw: 2.5, starCount: 5, allowsHalfSteps: false), 3, "整星步进：.rounded() 半进位向上")
        XCTAssertEqual(RatingGeometry.snapped(raw: -2, starCount: 5, allowsHalfSteps: true), 0, "负分钳到 0")
        XCTAssertEqual(RatingGeometry.snapped(raw: 99, starCount: 3, allowsHalfSteps: true), 3, "超分钳到 starCount")
    }

    func testSwitchStateDefaults() {
        let s = SwitchState(isOn: false)
        XCTAssertEqual(s.tone, .primary)
        XCTAssertTrue(s.isEnabled)
    }

    func testSegmentedStateDefaults() {
        let s = SegmentedState(items: ["A", "B", "C"])
        XCTAssertEqual(s.selectedIndex, 0)
        XCTAssertEqual(s.tone, .primary)
        XCTAssertTrue(s.isEnabled)
        XCTAssertFalse(s.isMomentary, "默认保持选中态")
    }

    func testSliderStateDefaults() {
        let s = SliderState(value: 0.5)
        XCTAssertEqual(s.min, 0)
        XCTAssertEqual(s.max, 1)
        XCTAssertEqual(s.step, 0)
        XCTAssertEqual(s.tone, .primary)
        XCTAssertTrue(s.isEnabled)
        XCTAssertTrue(s.reportsContinuously, "默认拖拽中实时上报")
    }

    func testChipStateDefaults() {
        let s = ChipState(title: "标签")
        XCTAssertEqual(s.tone, .primary)
        XCTAssertFalse(s.isSelected)
        XCTAssertTrue(s.isEnabled)
        XCTAssertNil(s.icon)
        XCTAssertFalse(s.showsCheckmark)
    }

    func testNoticeStateDefaults() {
        let s = NoticeState(title: "提示")
        XCTAssertNil(s.message)
        XCTAssertEqual(s.tone, .primary)
        XCTAssertNil(s.icon)
        XCTAssertFalse(s.showsClose)
        XCTAssertNil(s.autoDismissAfter, "默认不自动消失")
    }

    func testEmptyStateStateDefaults() {
        let s = EmptyStateState(title: "暂无数据")
        XCTAssertNil(s.message)
        XCTAssertNil(s.icon)
        XCTAssertNil(s.actionTitle)
        XCTAssertNil(s.secondaryActionTitle)
        XCTAssertEqual(s.tone, .primary)
    }

    // MARK: - 新批次（Stepper / DatePicker / TextView / ActivityIndicator）

    func testStepperStateDefaults() {
        let s = StepperState()
        XCTAssertEqual(s.value, 0)
        XCTAssertEqual(s.min, 0)
        XCTAssertEqual(s.max, 10)
        XCTAssertEqual(s.step, 1)
        XCTAssertFalse(s.wraps, "默认不到界回绕")
        XCTAssertTrue(s.autorepeat, "默认长按连发")
        XCTAssertEqual(s.tone, .primary)
        XCTAssertTrue(s.isEnabled)
    }

    func testDatePickerStateDefaults() {
        let s = DatePickerState()
        XCTAssertEqual(s.kind, .date)
        XCTAssertEqual(s.countDownDuration, 0)
        XCTAssertEqual(s.tone, .primary)
        XCTAssertTrue(s.isEnabled)
    }

    func testDatePickerCountDownClamp() {
        // 契约层钳制到「60 的倍数 + 非负」：越界值进不到 UIKit
        XCTAssertEqual(DatePickerState(countDownDuration: 90).countDownDuration, 120, "90s 就近取整到 60 的倍数 → 120")
        XCTAssertEqual(DatePickerState(countDownDuration: 30).countDownDuration, 60)
        XCTAssertEqual(DatePickerState(countDownDuration: 600).countDownDuration, 600, "整 60 倍数原样")
        XCTAssertEqual(DatePickerState(countDownDuration: -30).countDownDuration, 0, "负值钳到 0")
    }

    func testDatePickerKindMapping() {
        XCTAssertEqual(DatePickerKind.allCases.count, 4)
        XCTAssertEqual(DatePickerKind.countDown.uiMode, .countDownTimer)
        XCTAssertEqual(DatePickerKind.dateAndTime.uiMode, .dateAndTime)
        XCTAssertEqual(DatePickerKind.time.uiMode, .time)
    }

    func testDatePickerStateEquatable() {
        let date = Date(timeIntervalSince1970: 0)
        let a = DatePickerState(date: date, kind: .date)
        let b = DatePickerState(date: date, kind: .date)
        XCTAssertEqual(a, b)

        let c = DatePickerState(date: date, kind: .time)
        XCTAssertNotEqual(a, c, "kind 参与值比较")
    }

    func testActivityIndicatorStateDefaults() {
        let s = ActivityIndicatorState()
        XCTAssertFalse(s.isAnimating)
        XCTAssertEqual(s.size, .medium)
        XCTAssertEqual(s.tone, .primary)
        XCTAssertTrue(s.hidesWhenStopped, "默认停止即隐藏")
    }

    func testTextViewStateDefaults() {
        let s = TextViewState()
        XCTAssertEqual(s.text, "")
        XCTAssertEqual(s.placeholder, "")
        XCTAssertEqual(s.border, .roundedRect)
        XCTAssertEqual(s.keyboard, .standard)
        XCTAssertTrue(s.isEditable)
        XCTAssertNil(s.maxLength, "默认不限长")
    }

    // MARK: - 新批次二（PageControl / OTPField / IndexBar / PickerWheel）

    func testPageControlStateDefaults() {
        let s = PageControlState()
        XCTAssertEqual(s.pageCount, 0)
        XCTAssertEqual(s.currentPage, 0)
        XCTAssertEqual(s.tone, .neutral, "未选圆点默认灰色")
        XCTAssertEqual(s.currentTone, .primary, "选中圆点默认主色")
        XCTAssertTrue(s.hidesForSinglePage, "默认单页自动隐藏")
        XCTAssertTrue(s.isEnabled)
    }

    func testPageControlStateClamps() {
        XCTAssertEqual(PageControlState(pageCount: 5, currentPage: 9).currentPage, 4, "超上限收进 pageCount-1")
        XCTAssertEqual(PageControlState(pageCount: 5, currentPage: -3).currentPage, 0, "低于 0 收进 0")
        XCTAssertEqual(PageControlState(pageCount: 0, currentPage: 2).currentPage, 0, "无页时归 0")
        XCTAssertEqual(PageControlState(pageCount: -2).pageCount, 0, "页数钳非负")
    }

    func testOTPFieldStateDefaults() {
        let s = OTPFieldState()
        XCTAssertEqual(s.codeLength, 6)
        XCTAssertEqual(s.value, "")
        XCTAssertEqual(s.tone, .primary)
        XCTAssertFalse(s.isSecure, "默认不遮盖")
        XCTAssertTrue(s.isEnabled)
    }

    func testOTPFieldCodeLengthClamp() {
        XCTAssertEqual(OTPFieldState(codeLength: 10).codeLength, 8, "超上限收进 8")
        XCTAssertEqual(OTPFieldState(codeLength: 2).codeLength, 4, "低于下限收进 4")
        XCTAssertEqual(OTPFieldState(codeLength: 4).codeLength, 4)
        XCTAssertEqual(OTPFieldState(codeLength: 6).codeLength, 6)
    }

    func testIndexBarStateDefaults() {
        let s = IndexBarState()
        XCTAssertEqual(s.items.count, 26, "默认 A–Z 26 个")
        XCTAssertEqual(s.items.first, "A")
        XCTAssertEqual(s.items.last, "Z")
        XCTAssertEqual(s.tone, .neutral)
        XCTAssertEqual(s.activeTone, .primary)
        XCTAssertTrue(s.isEnabled)
    }

    func testIndexBarGeometry() {
        // 空数据 / 零高 → nil（安全）
        XCTAssertNil(IndexBarGeometry.index(forY: 10, height: 100, count: 0), "无条目返回 nil")
        XCTAssertNil(IndexBarGeometry.index(forY: 10, height: 0, count: 3), "高度 0 返回 nil")
        // 首末项钳制
        XCTAssertEqual(IndexBarGeometry.index(forY: 0, height: 260, count: 26), 0, "顶部映射首项")
        XCTAssertEqual(IndexBarGeometry.index(forY: 260, height: 260, count: 26), 25, "底部钳到末项")
        XCTAssertEqual(IndexBarGeometry.index(forY: -5, height: 260, count: 26), 0, "越界上方钳到首项")
        XCTAssertEqual(IndexBarGeometry.index(forY: 999, height: 260, count: 26), 25, "越界下方钳到末项")
        // 均分切换点
        XCTAssertEqual(IndexBarGeometry.index(forY: 120, height: 260, count: 2), 0, "中点以下归 0")
        XCTAssertEqual(IndexBarGeometry.index(forY: 131, height: 260, count: 2), 1, "过中点归 1")
    }

    func testPickerWheelStateDefaults() {
        let s = PickerWheelState()
        XCTAssertEqual(s.components, [["红", "绿", "蓝"], ["大", "中", "小"]])
        XCTAssertEqual(s.selectedRows, [0, 0])
        XCTAssertEqual(s.tone, .primary)
        XCTAssertTrue(s.isEnabled)
    }

    func testPickerWheelStateClamps() {
        // 数量对齐列数、值逐列钳进行数与空列兜底
        XCTAssertEqual(PickerWheelState(components: [["A", "B"], ["X"]], selectedRows: [5, 5]).selectedRows, [1, 0])
        XCTAssertEqual(PickerWheelState(components: [["A", "B"], ["X"]], selectedRows: [0]).selectedRows, [0, 0], "缺列补 0")
        XCTAssertEqual(PickerWheelState(components: [], selectedRows: [2]).selectedRows, [], "无列 → 空选中")
        XCTAssertEqual(PickerWheelState(components: [[]], selectedRows: [3]).selectedRows, [0], "空列 → 行 0")
    }

    func testPickerWheelStateEquatable() {
        let a = PickerWheelState(components: [["A", "B"], ["1"]], selectedRows: [1, 0])
        let b = PickerWheelState(components: [["A", "B"], ["1"]], selectedRows: [1, 0])
        XCTAssertEqual(a, b)

        let c = PickerWheelState(components: [["A", "B"], ["2"]], selectedRows: [1, 0])
        XCTAssertNotEqual(a, c, "数据不同判不等")
    }

    // MARK: - 功能扩展组件（ProgressBar / SearchField / Toast）

    func testProgressBarStateDefaults() {
        let s = ProgressBarState()
        XCTAssertEqual(s.progress, 0)
        XCTAssertEqual(s.tone, .primary)
        XCTAssertFalse(s.isIndeterminate)
    }

    func testProgressBarStateClamps() {
        // 契约层钳制到 [0,1]：越界值进不到视图
        XCTAssertEqual(ProgressBarState(progress: 1.5).progress, 1)
        XCTAssertEqual(ProgressBarState(progress: -0.5).progress, 0)
        XCTAssertEqual(ProgressBarState(progress: 0.37).progress, 0.37)
    }

    func testSearchFieldStateDefaults() {
        let s = SearchFieldState()
        XCTAssertEqual(s.text, "")
        XCTAssertEqual(s.placeholder, "搜索")
        XCTAssertEqual(s.tone, .primary)
        XCTAssertTrue(s.showsCancelButton)
        XCTAssertNil(s.debounceInterval, "默认每次变化立即上报")
        XCTAssertTrue(s.isEnabled)
    }

    func testSearchFieldStateEquatableDebounceDiffers() {
        let immediate = SearchFieldState()
        let debounced = SearchFieldState(debounceInterval: 0.3)
        XCTAssertNotEqual(immediate, debounced, "防抖档位参与值比较")
        XCTAssertEqual(debounced, SearchFieldState(debounceInterval: 0.3))
    }

    func testToastStateDefaults() {
        let s = ToastState(message: "已复制")
        XCTAssertNil(s.icon)
        XCTAssertEqual(s.tone, .primary)
        XCTAssertFalse(s.isPresented, "默认收起")
        XCTAssertNil(s.autoDismissAfter)
        XCTAssertTrue(s.dismissOnTap)
        XCTAssertEqual(s.bottomOffset, 24)
    }

    func testToastStateEquatable() {
        let a = ToastState(message: "已复制", icon: "checkmark", tone: .success)
        let b = ToastState(message: "已复制", icon: "checkmark", tone: .success)
        XCTAssertEqual(a, b)

        let c = ToastState(message: "已复制", icon: "checkmark", tone: .success, autoDismissAfter: 3)
        XCTAssertNotEqual(a, c, "自动消失档位参与值比较")
    }

    // MARK: - Equatable 早退语义

    func testButtonStateEquatableDiffersByStyle() {
        let a = ButtonState(title: "x")
        let b = ButtonState(title: "x", style: .danger)
        XCTAssertNotEqual(a, b)
    }

    func testAvatarImageIdentityEquality() {
        let image = UIImage()
        let a = AvatarState(title: "张", image: image)
        let b = AvatarState(title: "张", image: image)
        // 同一 UIImage 实例 → ==（Coordinator 值比较早退、不重绘）
        XCTAssertEqual(a, b)

        let c = AvatarState(title: "张", image: UIImage())
        // 不同实例（即使内容一样）→ !=，因为没有等值比较手段
        XCTAssertNotEqual(a, c)
    }

    func testAvatarBorderToneEquality() {
        let a = AvatarState(title: "李", borderTone: .primary)
        let b = AvatarState(title: "李", borderTone: .primary)
        XCTAssertEqual(a, b)
    }

    // MARK: - UIKit 样式映射 spot-check

    func testToneColorMapping() {
        XCTAssertEqual(ComponentPalette.color(for: .primary), .systemBlue)
        XCTAssertEqual(ComponentPalette.color(for: .success), .systemGreen)
        XCTAssertEqual(ComponentPalette.color(for: .danger), .systemRed)
    }

    func testStarColorMapping() {
        XCTAssertEqual(ComponentPalette.starColor(for: .gold), .systemYellow)
        XCTAssertEqual(ComponentPalette.starColor(for: .system), .tintColor)
    }

    func testButtonColorMapping() {
        let primary = ComponentPalette.buttonColors(for: .primary)
        XCTAssertEqual(primary.background, .systemBlue)
        XCTAssertEqual(primary.foreground, .white)
    }

    func testTextFieldBorderCases() {
        XCTAssertEqual(TextFieldBorder.allCases.count, 3)
    }

    // MARK: - 复杂视图（List / Grid / Carousel）

    func testListStateDefaults() {
        let s = ListState(rows: [])
        XCTAssertTrue(s.rows.isEmpty)
    }

    func testListRowEquatable() {
        let a = ListRow(id: "1", title: "行", leadingIcon: "doc", tone: .primary)
        let b = ListRow(id: "1", title: "行", leadingIcon: "doc", tone: .primary)
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.swipeActions.isEmpty, "默认不可滑")

        let c = ListRow(id: "1", title: "行", leadingIcon: "doc", tone: .danger)
        XCTAssertNotEqual(a, c)
    }

    func testListRowSwipeActionsDiffer() {
        let base = ListRow(id: "1", title: "行")
        let swipeable = ListRow(id: "1", title: "行", swipeActions: [ListSwipeAction(id: "del", title: "删除")])
        XCTAssertNotEqual(base, swipeable, "带滑动操作的行与不带的不相等")

        let same = ListRow(id: "1", title: "行", swipeActions: [ListSwipeAction(id: "del", title: "删除")])
        XCTAssertEqual(swipeable, same)
    }

    func testListSwipeActionEquatable() {
        let a = ListSwipeAction(id: "del", title: "删除")
        let b = ListSwipeAction(id: "del", title: "删除")
        XCTAssertEqual(a, b, "id + title + tone 全等才判等")
        XCTAssertEqual(a.tone, .danger, "默认删除色")

        let c = ListSwipeAction(id: "archive", title: "归档", tone: .primary)
        XCTAssertNotEqual(a, c)
    }

    func testGridCellBadge() {
        let plain = GridCell(id: "a", title: "相册")
        let badged = GridCell(id: "a", title: "相册", badge: "new")
        XCTAssertNil(plain.badge, "默认无角标")
        XCTAssertNotEqual(plain, badged, "badge 参与值比较")
    }

    func testBadgeFormatDisplayText() {
        // 纯函数：整数超过上限 → "99+"
        XCTAssertEqual(BadgeFormat.displayText("128", maxValue: 99), "99+")
        // 未超限原样
        XCTAssertEqual(BadgeFormat.displayText("5", maxValue: 99), "5")
        XCTAssertEqual(BadgeFormat.displayText("99", maxValue: 99), "99")
        // 非数字原样
        XCTAssertEqual(BadgeFormat.displayText("99+", maxValue: 99), "99+")
        XCTAssertEqual(BadgeFormat.displayText("abc", maxValue: 99), "abc")
        // nil 上限不截断
        XCTAssertEqual(BadgeFormat.displayText("128", maxValue: nil), "128")
    }

    func testGridStateDefaults() {
        let s = GridState(cells: [])
        XCTAssertEqual(s.columns, 3)

        // 列数钳制到至少 1
        XCTAssertEqual(GridState(cells: [], columns: 0).columns, 1)
    }

    func testGridCellHashable() {
        let cell = GridCell(id: "a", title: "相册", icon: "photo", tone: .primary)
        // Hashable：同名同值进 Set 归一；diffable 的 identity 依赖这个
        let set: Set<GridCell> = [cell, cell]
        XCTAssertEqual(set.count, 1)

        let other = GridCell(id: "a", title: "相册", icon: "photo", tone: .danger)
        XCTAssertNotEqual(cell, other)
    }

    // MARK: - 视图层冒烟（apply → 渲染路径回归）

    @MainActor
    func testGridColumnsRecomputeItemSize() {
        let view = GridBridgeView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        view.layoutIfNeeded()
        XCTAssertEqual(view.collectionView.bounds.width, 400, "前提：布局已把 collectionView 撑满")

        let cells = (0..<4).map { GridCell(id: "\($0)", title: "格\($0)") }
        view.apply(GridState(cells: cells, columns: 2))

        let layout = view.collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        let width = view.collectionView.bounds.width
        func expectedWidth(_ columns: Int) -> CGFloat {
            let insets = layout.sectionInset.left + layout.sectionInset.right
            let spacing = layout.minimumInteritemSpacing * CGFloat(columns - 1)
            return floor((max(width, 320) - insets - spacing) / CGFloat(columns))
        }

        // 2 列 → item 宽按 2 列均分
        let two = view.collectionView(view.collectionView,
                                      layout: layout,
                                      sizeForItemAt: IndexPath(item: 0, section: 0))
        XCTAssertEqual(two.width, expectedWidth(2))

        // cells 不变、仅列数 2 → 4：P0 修复路径，不再被 cells 早退吞掉
        view.apply(GridState(cells: cells, columns: 4))
        let four = view.collectionView(view.collectionView,
                                       layout: layout,
                                       sizeForItemAt: IndexPath(item: 0, section: 0))
        XCTAssertEqual(four.width, expectedWidth(4))
        XCTAssertGreaterThan(two.width, four.width, "4 列的格子应比 2 列窄")
    }

    @MainActor
    func testNewBatchBridgeViewsApplyAndTeardown() {
        // Stepper：apply 写值 + 色调；teardown 幂等可重复调
        let stepper = StepperBridgeView(frame: CGRect(x: 0, y: 0, width: 200, height: 34))
        stepper.apply(StepperState(value: 3, tone: .success))
        XCTAssertEqual(stepper.stepper.value, 3, "apply 应把值写进 UIStepper")
        stepper.apply(StepperState(value: 3, tone: .success))
        XCTAssertEqual(stepper.stepper.value, 3, "值未变再 apply 不变动")
        stepper.teardown()
        stepper.teardown()

        // DatePicker：countDown 时长取整写入；切回 date 模式写日期
        let picker = DatePickerBridgeView(frame: CGRect(x: 0, y: 0, width: 300, height: 40))
        picker.apply(DatePickerState(date: Date(), kind: .countDown, countDownDuration: 30))
        XCTAssertEqual(picker.picker.countDownDuration, 60, "30s 按 60 倍数取整")
        let fixed = Date(timeIntervalSince1970: 0)
        picker.apply(DatePickerState(date: fixed, kind: .date))
        XCTAssertEqual(picker.picker.date, fixed)
        picker.teardown()

        // TextView：下划线边框 + 占位符不崩；文本回写
        let field = TextViewBridgeView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        field.layoutIfNeeded()
        field.apply(TextViewState(text: "", placeholder: "占位", border: .underline))
        XCTAssertEqual(field.textView.text, "")
        field.apply(TextViewState(text: "你好", placeholder: "占位"))
        XCTAssertEqual(field.textView.text, "你好")
        field.teardown()

        // ActivityIndicator：起停 + 大尺寸不塌缩行高
        let spinner = ActivityIndicatorBridgeView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        spinner.apply(ActivityIndicatorState(isAnimating: true, size: .large))
        spinner.teardown()
        XCTAssertGreaterThanOrEqual(spinner.intrinsicContentSize.height, 24, "停止占位行高不塌缩")
    }

    @MainActor
    func testNewBatch2BridgeViewsApplyAndTeardown() {
        // PageControl：apply 写页数与当前页；teardown 幂等可重复调
        let dots = PageControlBridgeView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        dots.apply(PageControlState(pageCount: 5, currentPage: 3))
        XCTAssertEqual(dots.pageControl.numberOfPages, 5)
        XCTAssertEqual(dots.pageControl.currentPage, 3, "apply 应把当前页写进 UIPageControl")
        dots.teardown()
        dots.teardown()

        // OTPField：未聚焦时 apply 回写文本；intrinsic 宽随格数、高为盒高
        let otp = OTPFieldBridgeView(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        otp.apply(OTPFieldState(codeLength: 6, value: "123"))
        XCTAssertEqual(otp.field.text, "123", "未聚焦时 apply 应回写文本")
        XCTAssertEqual(otp.intrinsicContentSize.height, 44, "行高 = 盒高")
        XCTAssertEqual(otp.intrinsicContentSize.width, 6 * 44 + 5 * 10, "宽 = N 格 + (N-1) 间距")
        otp.apply(OTPFieldState(codeLength: 4, value: "12"))
        XCTAssertEqual(otp.intrinsicContentSize.width, 4 * 44 + 3 * 10, "改格数后 intrinsic 重算")
        otp.teardown()

        // IndexBar：默认 A–Z，apply items 重建 label 栈
        let bar = IndexBarBridgeView(frame: CGRect(x: 0, y: 0, width: 22, height: 300))
        XCTAssertEqual(bar.itemLabels.count, 26, "默认 A–Z 26 个")
        bar.apply(IndexBarState(items: ["A", "B", "C", "D"]))
        XCTAssertEqual(bar.itemLabels.count, 4, "apply 应重建 label 栈")
        XCTAssertEqual(bar.itemLabels.first?.text, "A")
        bar.teardown()

        // PickerWheel：数据源快照落库 + selectRow 落位；固定轮盘高
        let wheel = PickerWheelBridgeView(frame: CGRect(x: 0, y: 0, width: 300, height: 216))
        wheel.apply(PickerWheelState(components: [["红", "绿", "蓝"], ["大", "中"]], selectedRows: [1, 1]))
        XCTAssertEqual(wheel.picker.numberOfComponents, 2)
        XCTAssertEqual(wheel.picker.numberOfRows(inComponent: 0), 3)
        XCTAssertEqual(wheel.picker.selectedRow(inComponent: 0), 1, "selectRow 应落位到第 1 列")
        XCTAssertEqual(wheel.picker.selectedRow(inComponent: 1), 1, "selectRow 应落位到第 2 列")
        XCTAssertEqual(wheel.intrinsicContentSize.height, 216, "UIPickerView 固定轮盘高")
        wheel.teardown()
    }

    func testCarouselStateDefaults() {
        let s = CarouselState(slides: [])
        XCTAssertEqual(s.currentIndex, 0)
        XCTAssertNil(s.autoPlayInterval)
        XCTAssertTrue(s.isInfinite, "无限轮播应为默认行为")
    }

    func testCarouselSlideEquatable() {
        let a = CarouselSlide(id: "1", title: "新人礼", subtitle: "满 99 减 20", tone: .primary)
        let b = CarouselSlide(id: "1", title: "新人礼", subtitle: "满 99 减 20", tone: .primary)
        XCTAssertEqual(a, b)

        let c = CarouselSlide(id: "1", title: "新人礼", subtitle: nil)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - 无限轮播的核心数学（纯函数，无 UIKit）

    func testCarouselGeometryRenderedCount() {
        XCTAssertEqual(CarouselGeometry.renderedCount(realCount: 3, isInfinite: true), 9)
        XCTAssertEqual(CarouselGeometry.renderedCount(realCount: 3, isInfinite: false), 3)
        XCTAssertEqual(CarouselGeometry.renderedCount(realCount: 1, isInfinite: true), 1, "单页不循环")
        XCTAssertEqual(CarouselGeometry.renderedCount(realCount: 0, isInfinite: true), 0)
    }

    func testCarouselGeometryNormalizeMiddleBand() {
        // 中带 [3,6)：原样
        XCTAssertEqual(CarouselGeometry.normalize(4, realCount: 3, isInfinite: true), 4)
        XCTAssertEqual(CarouselGeometry.normalize(5, realCount: 3, isInfinite: true), 5)
        // 前进跨到 C 带开头 → 回 B 带同页（3N 前，同 slide）
        XCTAssertEqual(CarouselGeometry.normalize(6, realCount: 3, isInfinite: true), 3)   // slide 0
        XCTAssertEqual(CarouselGeometry.normalize(8, realCount: 3, isInfinite: true), 5)   // slide 2
        // 后退进 A 带 → 去 C 带同页，保留向后伸展空间
        XCTAssertEqual(CarouselGeometry.normalize(0, realCount: 3, isInfinite: true), 6)   // slide 0
        XCTAssertEqual(CarouselGeometry.normalize(2, realCount: 3, isInfinite: true), 8)   // slide 2
        // 有限模式原样
        XCTAssertEqual(CarouselGeometry.normalize(2, realCount: 3, isInfinite: false), 2)
        XCTAssertEqual(CarouselGeometry.normalize(0, realCount: 3, isInfinite: false), 0)
    }

    func testCarouselGeometryMiddleIsAlwaysForwardable() {
        // 自动播前强制收进中带：任何合法位置都收敛到 [N, 2N) 且同页
        for p in 0..<9 {
            let mid = CarouselGeometry.middle(p, realCount: 3, isInfinite: true)
            XCTAssertTrue((3..<6).contains(mid), "p=\(p) 应落回中带，实际 \(mid)")
            XCTAssertEqual(p % 3, mid % 3, "瞬移不换页")
        }
    }

    func testCarouselGeometryNearest() {
        // 就近拷贝：避免长距离回卷
        XCTAssertEqual(CarouselGeometry.nearest(1, realCount: 3, from: 4, isInfinite: true), 4)  // 原地
        XCTAssertEqual(CarouselGeometry.nearest(2, realCount: 3, from: 4, isInfinite: true), 5)  // 相邻
        XCTAssertEqual(CarouselGeometry.nearest(0, realCount: 3, from: 5, isInfinite: true), 6)  // C 带近
        XCTAssertEqual(CarouselGeometry.nearest(0, realCount: 3, from: 5, isInfinite: false), 0) // 有限不走拷贝
    }
}