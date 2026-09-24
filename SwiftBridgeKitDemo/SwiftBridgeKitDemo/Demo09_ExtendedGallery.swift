//
//  Demo09_ExtendedGallery.swift
//  SwiftBridgeKitDemo
//
//  Demo 09：组件扩展（SwiftBridgeComponents 新增：ProgressBar / SearchField / Toast）
//
//  三个新组件各占一节，沿用 Demo07 的 BridgeHost + 控制行热切换 ——
//  每次切换都走「值比较早退 → 差异映射」，不做全量重建。
//    · ProgressBar：determinate 进度 / indeterminate 转圈，tone 换色
//    · SearchField：取消钮 / 回车提交 / 可选防抖上报（UISearchBar 包装）
//    · Toast：底部浮出动画 + 自动消失（Timer 弱代理）+ 点按收起
//
//  自检方式：
//    1. ProgressBar 拖 Slider → 进度条即时跟进；开「不确定动画」→ 换转圈。
//    2. SearchField 键入 → 防抖关：逐字上报；开：停顿 0.3s 才上报。
//    3. SearchField 回车「搜索」→ 「最近提交」刷新；外部注入不抢光标。
//    4. Toast 开「弹出」→ 卡片从底部浮出；「3s 自动消失」→ 到点自动藏并计数。
//    5. 静置时控制台不应有组件打印。
//

import SwiftUI
import SwiftBridgeKit
import SwiftBridgeComponents

private typealias SBTone = SwiftBridgeComponents.ComponentTone

struct Demo09_ExtendedGalleryPage: View {

    var body: some View {
        List {
            ProgressSection()
            SearchSection()
            ToastSection()

            Section("自检清单") {
                Text("· ProgressBar 拖拽即时更新；不确定态转圈")
                Text("· SearchField 防抖：开/关两条上报路径")
                Text("· SearchField 回车提交、取消钮清空、外部注入不抢光标")
                Text("· Toast 浮出/收起有动画；到点自动消失由业务控制")
                Text("· Toast 点按只上报 .tapped，显隐由业务回写")
                Text("· 静置时控制台无组件日志")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("09 · 组件扩展")
    }
}

// MARK: - ProgressBar

private struct ProgressSection: View {
    @State private var progress: Float = 0.62
    @State private var tone: SBTone = .primary
    @State private var isIndeterminate = false

    var body: some View {
        Section("ProgressBar（进度条）") {
            BridgeHost(
                state: ProgressBarState(progress: progress, tone: tone, isIndeterminate: isIndeterminate),
                makeView: { ProgressBarBridgeView() },
                onIntent: { _ in }
            )
            .frame(height: 24)
            .listRowInsets(EdgeInsets())

            Slider(value: $progress, in: 0...1, step: 0.05)
            LabeledContent("进度", value: "\(Int(progress * 100))%")

            Picker("色调", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Toggle("不确定动画（转圈）", isOn: $isIndeterminate)
        }
    }
}

// MARK: - SearchField

private struct SearchSection: View {
    @State private var text = ""
    @State private var tone: SBTone = .primary
    @State private var showsCancel = true
    @State private var debounce = false
    @State private var lastSubmitted = "—"

    var body: some View {
        Section("SearchField（搜索框）") {
            BridgeHost(
                state: SearchFieldState(
                    text: text,
                    placeholder: "搜索商品 / 店铺",
                    tone: tone,
                    showsCancelButton: showsCancel,
                    debounceInterval: debounce ? 0.3 : nil
                ),
                makeView: { SearchFieldBridgeView() },
                onIntent: { intent in
                    switch intent {
                    case .textChanged(let value): text = value
                    case .submitted: lastSubmitted = text
                    case .cancelTapped: text = ""
                    }
                }
            )
            .listRowInsets(EdgeInsets())

            Button("外部注入：热搜·火锅") {
                text = "热搜·火锅"
            }

            Toggle("0.3s 防抖上报", isOn: $debounce)
            Toggle("显示取消钮", isOn: $showsCancel)
            Picker("色调", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            LabeledContent("最近提交", value: lastSubmitted)
        }
    }
}

// MARK: - Toast

private struct ToastSection: View {
    @State private var isPresented = false
    @State private var autoDismiss = false
    @State private var showsIcon = true
    @State private var tone: SBTone = .primary
    @State private var tapCount = 0
    @State private var autoCount = 0

    var body: some View {
        Section("Toast（浮动消息）") {
            // 容器区：给浮层一个可浮出的底部空间
            ZStack {
                BridgeHost(
                    state: ToastState(
                        message: "已复制到剪贴板",
                        icon: showsIcon ? "checkmark.circle.fill" : nil,
                        tone: tone,
                        isPresented: isPresented,
                        autoDismissAfter: autoDismiss ? 3 : nil
                    ),
                    makeView: { ToastBridgeView() },
                    onIntent: { intent in
                        switch intent {
                        case .tapped: isPresented = false; tapCount += 1
                        case .autoDismissed: isPresented = false; autoCount += 1
                        }
                    }
                )
            }
            .frame(height: 140)
            .listRowInsets(EdgeInsets())

            Toggle("弹出", isOn: $isPresented)
            Toggle("3s 自动消失", isOn: $autoDismiss)
            Toggle("图标", isOn: $showsIcon)
            Picker("色调", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Button("收起", action: { isPresented = false })
            LabeledContent("点按消失次数", value: "\(tapCount)")
            LabeledContent("自动消失次数", value: "\(autoCount)")
        }
    }
}

#Preview {
    NavigationStack {
        Demo09_ExtendedGalleryPage()
    }
}