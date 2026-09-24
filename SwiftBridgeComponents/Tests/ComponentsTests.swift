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