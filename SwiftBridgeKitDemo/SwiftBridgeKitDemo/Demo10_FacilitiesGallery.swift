//
//  Demo10_FacilitiesGallery.swift
//  SwiftBridgeKitDemo
//
//  Demo 10：三项纵向设施（主题可注入 / 无障碍全量 / 弹层容器）
//
//  这是「设施」主题的第一页 Demo，围绕三件事：
//    · 主题可注入：ComponentTheme 全局 + BridgeHost 每桥 `theme:` 覆盖。
//      - 全局 `ComponentTheme.current` 是**启动时注入**（变更不重绘已挂载视图）；
//      - 运行时换肤走**每桥 override**（这里用 @State theme 逐个传）；
//      - 动态色随系统暗黑自动切换（无需重跑 apply）。
//    · 无障碍：组件默认自带（库内派生 label），业务可注入覆盖（BridgeHost
//      新参数 accessibilityLabel/Hint/Value）；无头模拟器读不出 VoiceOver，
//      用 UIAccessibility.post(.announcement) + 控制台 print 代听。
//    · 弹层容器：OverlayManager 窗口注入式 presenter，不走 present(_:)，
//      与 SwiftUI sheet / navigation 零冲突；Dialog / ActionSheet / BottomSheet
//      三个弹层组件 + overlayPresent 门面。
//
//  自检方式：
//    1. 主题节：切「默认 / 品牌」，Button / Switch / Chip / Rating / ProgressBar
//       五桥颜色一起联动（每桥 override 重放）；训练注释在代码里。
//    2. 无障碍节：点「播报按钮」→ 控制台打出各桥解析后的 label/注释组合。
//    3. 弹层节：三按钮分别弹 Dialog / ActionSheet / BottomSheet，
//       BottomSheet 连选不自动关、取消才关；onIntent 回显、onDismiss 清状态。
//    4. 暗黑切换：切 Dark 看五桥 + 弹层跟随系统语义色。
//    5. 静置时控制台不应有组件打印。
//

import SwiftUI
import SwiftBridgeKit
import SwiftBridgeComponents

struct Demo10_FacilitiesGalleryPage: View {

    var body: some View {
        List {
            ThemeSection()
            AccessibilitySection()
            OverlaySection()

            Section("自检清单") {
                Text("· 主题：Picker 切默认/品牌 → 五桥联动重放，暗黑同步")
                Text("· 无障碍：播报按钮打出每桥 label，业务注入可覆盖默认")
                Text("· Dialog：点动作先抛 .tapped 再请求关闭")
                Text("· ActionSheet：含独立取消区，任何项点击即关")
                Text("· BottomSheet：行被点只抛 .changed；取消才关、连选不自动关")
                Text("· 弹层走 OverlayManager，SwiftUI sheet 不冲突")
                Text("· 静置时控制台无组件日志")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("10 · 三项设施")
    }
}

// MARK: - 主题可注入

private enum DemoThemeChoice: String, CaseIterable, Identifiable {
    case standard = "默认（系统色）"
    case brand = "品牌（自定义）"

    var id: String { rawValue }

    /// 每桥 override 传入的具体主题。
    var theme: ComponentTheme {
        switch self {
        case .standard: return .default
        case .brand: return .brand
        }
    }
}

private struct ThemeSection: View {
    @State private var choice: DemoThemeChoice = .standard
    @State private var rating: Double = 4.5
    @State private var progress: Float = 0.62
    @State private var chipSelected = false

    var body: some View {
        Section {
            Picker("主题", selection: $choice) {
                ForEach(DemoThemeChoice.allCases) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)

            Text("教学点：全局 `ComponentTheme.current` 是启动注入，运行时换肤走每桥 `theme:` override —— 这里五桥共用同一个 @State，切换即联动重放。暗黑由 DynamicColor 自动跟随，无需重开。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // 五个桥视图都传 theme: choice.theme —— coordinator 在主题变化时强制重放
            BridgeHost(
                state: ButtonState(title: "立即加入", style: .primary, size: .regular,
                                   isEnabled: true),
                makeView: { ButtonBridgeView() },
                onIntent: { _ in },
                theme: choice.theme
            )
            .frame(height: 48)
            .listRowInsets(EdgeInsets())

            BridgeHost(
                state: SwitchState(isOn: true, tone: .primary, isEnabled: true),
                makeView: { SwitchBridgeView() },
                onIntent: { _ in },
                theme: choice.theme
            )
            .frame(height: 36)
            .listRowInsets(EdgeInsets())

            BridgeHost(
                state: ChipState(title: "标签", tone: .primary, isSelected: chipSelected,
                                 isEnabled: true, icon: "tag.fill", showsCheckmark: true),
                makeView: { ChipBridgeView() },
                onIntent: { _ in chipSelected.toggle() },
                theme: choice.theme
            )
            .frame(height: 36)
            .listRowInsets(EdgeInsets())

            BridgeHost(
                state: RatingState(rating: rating, starCount: 5, isEnabled: true,
                                   starTone: .gold),
                makeView: { RatingBridgeView() },
                onIntent: { if case .changed(let v) = $0 { rating = v } },
                theme: choice.theme
            )
            .frame(height: 40)
            .listRowInsets(EdgeInsets())

            BridgeHost(
                state: ProgressBarState(progress: progress, tone: .primary),
                makeView: { ProgressBarBridgeView() },
                onIntent: { _ in },
                theme: choice.theme
            )
            .frame(height: 24)
            .listRowInsets(EdgeInsets())
        } header: {
            Text("主题可注入")
        } footer: {
            Text("品牌主题把 primary 换紫、danger 换酒红、星色换金 —— 五桥联动重放即证每桥 override 生效。")
        }
    }
}

// MARK: - 无障碍全量

private struct AccessibilitySection: View {
    @State private var chipSelected = false
    @State private var announced = "—"

    /// 每桥解析出的「VoiceOver 会读的文本」。
    /// 无头模拟器无法真朗读，这里把组件默认 label 组织成一段给人念的文字。
    private var speech: String {
        "按钮：立即加入。开关：开。标签：\(chipSelected ? "已选中" : "未选中")。评分：4.5 分，满分 5。进度：62%。"
    }

    var body: some View {
        Section("无障碍全量") {
            Text("教学点：组件库默认自带无障碍（库内派生 label），业务可注入覆盖（BridgeHost 的 accessibilityLabel/Hint/Value 非 nil 才写）。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // 业务注入覆盖示例
            BridgeHost(
                state: ButtonState(title: "立即加入", style: .primary, size: .regular,
                                   isEnabled: true),
                makeView: { ButtonBridgeView() },
                onIntent: { _ in },
                accessibilityLabel: "业务覆盖：立即加入",
                accessibilityHint: "双击开始申请流程",
                accessibilityValue: nil
            )
            .frame(height: 48)
            .listRowInsets(EdgeInsets())

            BridgeHost(
                state: ChipState(title: "库默认可读", tone: .neutral, isSelected: chipSelected,
                                 isEnabled: true, icon: "tag.fill", showsCheckmark: true),
                makeView: { ChipBridgeView() },
                onIntent: { _ in chipSelected.toggle() },
                accessibilityLabel: nil
            )
            .frame(height: 36)
            .listRowInsets(EdgeInsets())

            Button("播报无障碍摘要") {
                announced = speech
                print("[Demo10 a11y] \(announced)")
                UIAccessibility.post(notification: .announcement, argument: announced)
            }
            LabeledContent("控制台/播报", value: announced)
        }
    }
}

// MARK: - 弹层容器

private struct OverlaySection: View {
    @State private var showDialog = false
    @State private var showActionSheet = false
    @State private var showBottomSheet = false

    /// BottomSheet 连选：业务留下最新选中行，回调里把选择同步下行。
    @State private var selectedColor = "red"
    @State private var lastIntent = "—"

    private let colors: [(id: String, title: String)] = [
        ("red", "红"), ("blue", "蓝"), ("green", "绿"), ("purple", "紫"),
    ]

    var body: some View {
        Section("弹层容器") {
            Text("教学点：OverlayManager 窗口注入式 presenter（不走 present(_:)），与 SwiftUI sheet / navigation 零冲突；单弹层 LIFO 替换。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // 门面绑定 isPresented，按钮动作只需要把绑定置真（收起由容器自关 + onDismiss 回写）
            Button("弹 Dialog（居中）") { showDialog = true }
                .overlayPresent(isPresented: $showDialog, state: dialogState, makeView: {
                    DialogBridgeView()
                }, onIntent: { intent in
                    if case .tapped(let action) = intent {
                        lastIntent = "Dialog · \(action.title)"
                    } else if case .close = intent {
                        lastIntent = "Dialog · 关闭"
                    }
                }, onDismiss: { showDialog = false })

            Button("弹 ActionSheet（底部）") { showActionSheet = true }
                .overlayPresent(isPresented: $showActionSheet, state: actionState, makeView: {
                    ActionSheetBridgeView()
                }, options: OverlayPresentation(placement: .bottom), onIntent: { intent in
                    if case .tapped(let item) = intent {
                        lastIntent = "ActionSheet · \(item.title)"
                    }
                }, onDismiss: { showActionSheet = false })

            Button("弹 BottomSheet 选色（当前：\(selectedColor)）") { showBottomSheet = true }
                .overlayPresent(isPresented: $showBottomSheet, state: bottomState, makeView: {
                    BottomSheetBridgeView()
                }, options: OverlayPresentation(placement: .bottom), onIntent: { intent in
                    if case .changed(let id) = intent {
                        selectedColor = id
                        lastIntent = "BottomSheet · 选中 \(id)（不自动关）"
                    } else if case .canceled = intent {
                        lastIntent = "BottomSheet · 取消"
                    }
                }, onDismiss: { showBottomSheet = false })

            LabeledContent("最近意图", value: lastIntent)
        }
    }

    private var dialogState: DialogState {
        DialogState(title: "删除这条记录？",
                    message: "删除后不可恢复。",
                    hideCloseButton: false,
                    actions: [
                        .init(id: "cancel", title: "取消", style: .secondary),
                        .init(id: "delete", title: "删除", style: .danger),
                    ])
    }

    private var actionState: ActionSheetState {
        ActionSheetState(title: "导出数据",
                         message: "选择导出格式",
                         items: [
                             .init(id: "pdf", title: "存为 PDF"),
                             .init(id: "csv", title: "存为 CSV", tone: .primary),
                             .init(id: "cancel", title: "取消", cancel: true),
                         ])
    }

    private var bottomState: BottomSheetState {
        BottomSheetState(title: "选择颜色",
                         rows: colors.map { row in
                             BottomSheetRow(id: row.id, title: row.title,
                                            selected: row.id == selectedColor)
                         },
                         cancelAvailable: true)
    }
}

#Preview {
    NavigationStack {
        Demo10_FacilitiesGalleryPage()
    }
}