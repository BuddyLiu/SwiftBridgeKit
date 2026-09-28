//
//  ThemeAccessibility_D.swift
//  SwiftBridgeComponentsTests
//
//  复用池组件（List / Grid / Carousel）主题化 + 无障碍改造的回归测试：
//    · 主题变化（同值 apply）不崩、不丢数据 —— 组件必须主动重画（themeChanged 强制重放）
//    · List / Grid 的 cell 级无障碍聚合（label / value 及复用归零）
//    · Carousel 换肤强制重建页面
//

import XCTest
@testable import SwiftBridgeComponents

@MainActor
final class ThemeAccessibilityDTests: XCTestCase {

    // MARK: - 主题化：同值重放不崩、不丢数据

    func testThemeChangeReappliesSnapshot() {
        // List 桥：首次 apply 落 3 行；仅主题变化（同值 apply）也必须强制重画，不崩、行数不变
        let view = ListBridgeView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        view.layoutIfNeeded()
        let rows = (0..<3).map { ListRow(id: "\($0)", title: "行\($0)") }

        view.apply(ListState(rows: rows))
        view.layoutIfNeeded()
        XCTAssertEqual(view.tableView.numberOfRows(inSection: 0), 3, "首次 apply 应落 3 行")
        XCTAssertEqual(view.tableView.visibleCells.count, 3, "3 行应全部可见")

        // 主题切换：数据同值走快照早退，若没有 themeChanged 强制重画，颜色层看不到新主题
        view.theme = ComponentTheme.brand
        view.apply(ListState(rows: rows))
        view.layoutIfNeeded()
        XCTAssertEqual(view.tableView.numberOfRows(inSection: 0), 3, "主题重绘后行数不变")
        XCTAssertEqual(view.tableView.visibleCells.count, 3, "主题重绘后可见 cell 仍在")

        view.teardown()
    }

    // MARK: - List：cell 级无障碍聚合

    func testListCellA11yComposition() {
        let view = ListBridgeView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        view.layoutIfNeeded()
        let row = ListRow(id: "1", title: "设置", subtitle: "通用", trailingText: "已开启")
        view.apply(ListState(rows: [row]))
        view.layoutIfNeeded()

        let cells = view.tableView.visibleCells
        XCTAssertEqual(cells.count, 1, "单行应可见")
        guard let cell = cells.first as? ListRowCell else {
            return XCTFail("首格应为 ListRowCell")
        }

        XCTAssertTrue(cell.isAccessibilityElement, "整行应作为单个可访问元素")
        XCTAssertEqual(cell.accessibilityTraits, [.button])
        let label = cell.accessibilityLabel ?? ""
        XCTAssertTrue(label.contains("设置"), "label 应含 title")
        XCTAssertTrue(label.contains("通用"), "label 应含 subtitle")
        XCTAssertFalse(label.contains("已开启"), "trailingText 不应进 label")
        XCTAssertEqual(cell.accessibilityValue, "已开启", "trailingText 作 value")

        // 复用归零：防脏复用把上一行的 label/value 串到下一行
        cell.prepareForReuse()
        XCTAssertNil(cell.accessibilityLabel, "复用后 label 归零")
        XCTAssertNil(cell.accessibilityValue, "复用后 value 归零")

        view.teardown()
    }

    // MARK: - Grid：cell 级无障碍聚合

    func testGridCellA11yLabelTitle() {
        let view = GridBridgeView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        view.layoutIfNeeded()
        view.apply(GridState(cells: [GridCell(id: "1", title: "相册", badge: "new")]))
        view.layoutIfNeeded()

        let cells = view.collectionView.visibleCells
        XCTAssertEqual(cells.count, 1, "单格应可见")
        guard let item = cells.first as? GridItemCell else {
            return XCTFail("首格应为 GridItemCell")
        }

        XCTAssertTrue(item.isAccessibilityElement, "整格应作为单个可访问元素")
        XCTAssertEqual(item.accessibilityTraits, [.button])
        XCTAssertEqual(item.accessibilityLabel, "相册", "label = title")
        XCTAssertEqual(item.accessibilityValue, "new", "badge 作 value")

        // 复用归零：防脏复用把上一格的 label/value 串到下一格
        item.prepareForReuse()
        XCTAssertNil(item.accessibilityLabel, "复用后 label 归零")
        XCTAssertNil(item.accessibilityValue, "复用后 value 归零")

        view.teardown()
    }

    // MARK: - Carousel：换肤强制重建页面

    func testCarouselThemeRedraw() {
        let view = CarouselBridgeView(frame: CGRect(x: 0, y: 0, width: 400, height: 180))
        view.layoutIfNeeded()
        let slides = [
            CarouselSlide(id: "1", title: "新人礼", subtitle: "满 99 减 20"),
            CarouselSlide(id: "2", title: "大牌日"),
        ]

        view.apply(CarouselState(slides: slides))
        view.layoutIfNeeded()
        XCTAssertEqual(view.pageViews.count, 6, "无限轮播 3N = 6 页")

        // 主题切换：数据同值时页面不自动重建，themeChanged 必须强制 rebuildPages（不崩、页数不变）
        view.theme = ComponentTheme.brand
        view.apply(CarouselState(slides: slides))
        view.layoutIfNeeded()
        XCTAssertEqual(view.pageViews.count, 6, "换肤重建后仍 6 页")

        view.teardown()
    }
}