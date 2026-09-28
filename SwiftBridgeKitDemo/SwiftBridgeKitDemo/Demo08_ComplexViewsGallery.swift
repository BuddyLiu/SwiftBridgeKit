//
//  Demo08_ComplexViewsGallery.swift
//  SwiftBridgeKitDemo
//
//  Demo 08：复杂视图（SwiftBridgeComponents 容器/导航类组件）
//
//  三个收编自 Demo04-06 教学模式的容器组件 + 两个导航指标组件，各占一节：
//  List / Grid / Carousel / PageControl / IndexBar。每节 BridgeHost + 控制区，
//  验证「下行命令 vs 上行意图」的边界：
//    · List 动态增删 → diff 早退、不走多余 reload
//    · Grid diffable → 插入/移动有动画
//    · Carousel 自动播 → Timer 走弱代理、teardown 停干净；
//      「跳第 1 页」是下行命令 → 程序化滚动且不反向上报
//    · PageControl 程序化跳页 → 同理只下行不反向上报
//    · IndexBar 无手势识别器 → touches 直接驱动，热区换算走纯函数
//
//  ⚠️ 组件包的枚举名与 SwiftUI 自带类型撞名（ComponentTone），本页用 `SBTone` 别名消歧。
//
//  自检方式：
//    1. List 点「加一行」→ 行即时出现；不动数据时重绘 → 不触发 reload。
//    2. Grid 点「加一项/打乱」→ 有插入/移动动画，不是整屏闪。
//    3. Carousel 开「自动播」→ 每 2 秒换一页，圆点跟随；关掉 → 停住。
//    4. Carousel 点「跳第 1 页」→ 滚过去但不冒「当前页」更新（下行 ≠ 上行）。
//    5. PageControl 点「跳第 3 页」→ 圆点移动但不冒「当前页」更新（同理）。
//    6. IndexBar 拖动 → 按字母去重上报、跨字母轻震；松手高亮清除。
//    7. 页面静置时控制台不应有组件打印。
//

import SwiftUI
import SwiftBridgeKit
import SwiftBridgeComponents

// MARK: - 组件枚举别名（消歧）

private typealias SBTone = SwiftBridgeComponents.ComponentTone

struct Demo08_ComplexViewsGalleryPage: View {

    var body: some View {
        List {
            ListSection()
            GridSection()
            CarouselSection()
            PageControlSection()
            IndexBarSection()

            Section("自检清单") {
                Text("· List 动态增删即时刷新、无数据时重绘不 reload")
                Text("· List 左滑「删除」→ 业务删行回写，复用池无野指针")
                Text("· Grid diffable 增量：插入/打乱有动画；角标开关全量带出")
                Text("· Carousel 自动播走弱代理 Timer，翻页圆点跟随")
                Text("· 无限轮播开 → 首尾无缝、永不到头；关 → 会回弹")
                Text("· 下行命令（Carousel/PageControl 跳页）不反向上报")
                Text("· IndexBar 拖动按字母去重上报、跨字母轻震")
                Text("· 静置时控制台无组件日志")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("08 · 复杂视图")
    }
}

// MARK: - List

private struct ListSection: View {
    @State private var rows: [ListRow] = [
        ListRow(id: "1", title: "消息中心", subtitle: "3 条未读", leadingIcon: "bell.fill", tone: .primary, trailingText: "刚刚"),
        ListRow(id: "2", title: "我的订单", subtitle: "查看全部订单", leadingIcon: "bag.fill", tone: .success, trailingText: "2 笔"),
        ListRow(id: "3", title: "优惠券", subtitle: "双十一专享", leadingIcon: "ticket.fill", tone: .warning, trailingText: "5 张"),
        ListRow(id: "4", title: "设置", leadingIcon: "gearshape.fill", tone: .neutral, showsChevron: false),
    ]
    @State private var rowID = 100
    @State private var lastSelected = "—"
    @State private var allowsSwipeDelete = true

    /// 上行删除意图映射：只做「去重」，真正删行由业务回写 → apply 差分 reload。
    private var displayRows: [ListRow] {
        allowsSwipeDelete
            ? rows.map { row in
                var row = row
                row.swipeActions = [ListSwipeAction(id: "del-\(row.id)", title: "删除")]
                return row
            }
            : rows
    }

    var body: some View {
        Section("List（通用列表）") {
            BridgeHost(
                state: ListState(rows: displayRows),
                makeView: { ListBridgeView() },
                onIntent: { intent in
                    switch intent {
                    case .selected(let row): lastSelected = row.title
                    case .swipeAction(let row, _):
                        // 左滑「删除」→ 业务从 @State 移除该 id ⊇ 下行闭环
                        rows.removeAll { $0.id == row.id }
                    }
                }
            )
            .frame(height: 300)
            .listRowInsets(EdgeInsets())

            Button("加一行（末尾）") {
                rows.append(ListRow(
                    id: "\(rowID)",
                    title: "新入口 \(rowID)",
                    subtitle: "动态插入",
                    leadingIcon: "plus.circle.fill",
                    tone: .danger
                ))
                rowID += 1
            }
            Button("清空") { rows = [] }
            Toggle("行可左滑删除", isOn: $allowsSwipeDelete)
                .font(.subheadline)
            LabeledContent("已选", value: lastSelected)
        }
    }
}

// MARK: - Grid

private struct GridSection: View {
    private let seed = [
        GridCell(id: "a", title: "相册", icon: "photo.fill", tone: .primary),
        GridCell(id: "b", title: "收藏", icon: "heart.fill", tone: .danger),
        GridCell(id: "c", title: "卡券", icon: "ticket.fill", tone: .warning),
        GridCell(id: "d", title: "订单", icon: "bag.fill", tone: .success),
        GridCell(id: "e", title: "足迹", icon: "eye.fill", tone: .neutral),
        GridCell(id: "f", title: "消息", icon: "bell.fill", tone: .primary),
    ]
    @State private var cells: [GridCell]
    @State private var columns = 3
    @State private var cellID = 1000
    @State private var lastTapped = "—"
    @State private var showsBadges = true

    init() {
        _cells = State(initialValue: seed)
    }

    /// 角标开关映射：统一在「提交给桥」前给单元格贴角标，identity 不变 → diffable 增量动画。
    private var displayCells: [GridCell] {
        showsBadges
            ? cells.map { GridCell(id: $0.id, title: $0.title, icon: $0.icon, tone: $0.tone, badge: "new") }
            : cells.map { GridCell(id: $0.id, title: $0.title, icon: $0.icon, tone: $0.tone, badge: nil) }
    }

    var body: some View {
        Section("Grid（宫格 + diffable 增量）") {
            BridgeHost(
                state: GridState(cells: displayCells, columns: columns),
                makeView: { GridBridgeView() },
                onIntent: { intent in
                    if case .tapped(let cell) = intent { lastTapped = cell.title }
                }
            )
            .frame(height: 260)
            .listRowInsets(EdgeInsets())

            Button("加一项（末尾）") {
                cells.append(GridCell(id: "\(cellID)", title: "新格 \(cellID)", icon: "sparkles", tone: .primary))
                cellID += 1
            }
            Button("打乱顺序") { cells.shuffle() }
            Toggle("列数 = \(columns)", isOn: Binding(
                get: { columns == 3 },
                set: { columns = $0 ? 4 : 3 }
            ))
            Toggle("单元格角标（new）", isOn: $showsBadges)
                .font(.subheadline)
            LabeledContent("已点", value: lastTapped)
        }
    }
}

// MARK: - Carousel

private struct CarouselSection: View {
    private let slides = [
        CarouselSlide(id: "1", title: "今日特惠", subtitle: "全场 5 折起", tone: .primary),
        CarouselSlide(id: "2", title: "会员日", subtitle: "双倍积分", tone: .success),
        CarouselSlide(id: "3", title: "新品首发", subtitle: "快来看看", tone: .warning),
    ]
    /// 下行命令：外部注入「跳到第 N 页」。
    @State private var currentIndex = 0
    /// 上行意图回声：只来自 .pageChanged（用户滑动 / 自动播）。
    @State private var pageFromIntent = 0
    @State private var autoPlay = false
    @State private var isInfinite = true
    @State private var lastTapped = "—"
    @State private var timerTickCount = 0

    var body: some View {
        Section("Carousel（轮播 + Timer + 无限回绕）") {
            BridgeHost(
                state: CarouselState(
                    slides: slides,
                    currentIndex: currentIndex,
                    autoPlayInterval: autoPlay ? 2.0 : nil,
                    isInfinite: isInfinite
                ),
                makeView: { CarouselBridgeView() },
                onIntent: { intent in
                    switch intent {
                    case .pageChanged(let index):
                        pageFromIntent = index
                        timerTickCount += 1
                    case .tapped(let slide):
                        lastTapped = slide.title
                    }
                }
            )
            .frame(height: 180)
            .listRowInsets(EdgeInsets())

            Toggle("自动播放（2s）", isOn: $autoPlay)
            Toggle("无限轮播（首尾无缝）", isOn: $isInfinite)
            Button("下行命令：跳第 1 页") { currentIndex = 1 }
            LabeledContent("上行当前页", value: "\(pageFromIntent)")
            LabeledContent("翻页累计", value: "\(timerTickCount)")
            LabeledContent("点过的页", value: lastTapped)
            Text("自检：开自动播后可放任不管——页永远换不完、圆点 0↔2 来回；关无限 → 到第 3 页回弹。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - PageControl

private struct PageControlSection: View {
    @State private var pageCount = 5
    @State private var currentPage = 0
    @State private var tone: SBTone = .neutral
    @State private var currentTone: SBTone = .primary
    @State private var hidesForSinglePage = true
    @State private var isEnabled = true
    @State private var pageFromIntent = -1

    var body: some View {
        Section("PageControl（分页点）") {
            BridgeHost(
                state: PageControlState(
                    pageCount: pageCount,
                    currentPage: currentPage,
                    tone: tone,
                    currentTone: currentTone,
                    hidesForSinglePage: hidesForSinglePage,
                    isEnabled: isEnabled
                ),
                makeView: { PageControlBridgeView() },
                onIntent: { intent in
                    switch intent {
                    case .pageChanged(let page): pageFromIntent = page   // 只来自用户点圆点
                    }
                }
            )
            .listRowInsets(EdgeInsets())

            Stepper("页数：\(pageCount)", value: $pageCount, in: 0...8)
            // 下行命令：程序化赋值 currentPage → 不触发 valueChanged → 不反向上报
            Button("下行命令：跳第 3 页") { currentPage = 2 }

            Picker("未选圆点", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Picker("选中圆点", selection: $currentTone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Toggle("单页自动隐藏", isOn: $hidesForSinglePage)
            Toggle("可用", isOn: $isEnabled)
            LabeledContent("上行当前页", value: pageFromIntent < 0 ? "(尚无)" : "\(pageFromIntent)")
            Text("自检：点「跳第 3 页」→ 圆点移动但上行当前页不变（下行 ≠ 上行）。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - IndexBar

private struct IndexBarSection: View {
    @State private var items = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init)
    @State private var tone: SBTone = .neutral
    @State private var activeTone: SBTone = .primary
    @State private var isEnabled = true
    @State private var lastLetter = "—"

    var body: some View {
        Section("IndexBar（字母索引）") {
            HStack(spacing: 16) {
                // 右缘窄条：高由外部 frame 给，宽走 intrinsic
                BridgeHost(
                    state: IndexBarState(
                        items: items,
                        tone: tone,
                        activeTone: activeTone,
                        isEnabled: isEnabled
                    ),
                    makeView: { IndexBarBridgeView() },
                    onIntent: { intent in
                        switch intent {
                        case .changed(let letter): lastLetter = letter
                        }
                    }
                )
                .frame(height: 300)

                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 8) {
                    Text("当前")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(lastLetter)
                        .font(.title2.bold())
                }
            }
            .listRowInsets(EdgeInsets())

            // 换一版自定义条目 → apply 重建 label 栈（默认 A–Z 之外的自绘验证）
            Button("换成中文字首「张李王赵」") { items = ["张", "李", "王", "赵"] }

            Picker("常态字色", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Picker("高亮字色", selection: $activeTone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Toggle("可用", isOn: $isEnabled)
            LabeledContent("最近字母", value: lastLetter)
            Text("自检：拖动索引条 → 跨字母才上报 + 轻震；松手高亮清除。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        Demo08_ComplexViewsGalleryPage()
    }
}