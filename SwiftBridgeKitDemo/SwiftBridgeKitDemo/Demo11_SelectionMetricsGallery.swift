//
//  Demo11_SelectionMetricsGallery.swift
//  SwiftBridgeKitDemo
//
//  Demo 11：选择与指标（SwiftBridgeComponents 新增：Checkbox / RadioGroup /
//  StepIndicator / Sparkline）
//
//  四个新组件各占一节，沿用 Demo09 的 BridgeHost + 控制行热切换 ——
//  每次切换都走「值比较早退 → 差异映射」，不做全量重建。
//    · Checkbox：单个复选框行，点按只上报 .tapped，选中态由业务回写
//    · RadioGroup：纵向单选组，点行上报 .changed(id)，选中由业务回写
//    · StepIndicator：绘制型步骤条（勾 ✓ / 当前步 / 未来步 + 完成段连线）
//    · Sparkline：绘制型迷你折线图（可选浅色填充带）
//
//  自检方式：
//    1. Checkbox 点行 / 外部注入 → 勾选框填色 + checkmark 同步。
//    2. RadioGroup 换选某行 → 勾选圈跟随；「清空选择」回写 nil。
//    3. StepIndicator 前进/后退 → 勾 ✓ 与连接线推进；当前步加粗描边。
//    4. Sparkline 重新生成 → 折线与填充带变化；关填充只剩线。
//    5. 色调 Picker 全部组件联动换色（每桥走同一 @State 重放）。
//    6. 静置时控制台不应有组件打印。
//

import SwiftUI
import SwiftBridgeKit
import SwiftBridgeComponents

private typealias SBTone = SwiftBridgeComponents.ComponentTone

struct Demo11_SelectionMetricsGalleryPage: View {

    var body: some View {
        List {
            CheckboxSection()
            RadioGroupSection()
            StepIndicatorSection()
            SparklineSection()

            Section("自检清单") {
                Text("· Checkbox 只上报 .tapped，选中态由业务回写")
                Text("· RadioGroup 点行只上报 .changed(id)，选中由业务回写")
                Text("· StepIndicator / Sparkline 纯展示（NoIntent）")
                Text("· 步骤条勾 ✓ + 完成后连线随进度推进")
                Text("· 趋势图填充带可按需关闭，序列自适应画布")
                Text("· 静置时控制台无组件日志")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("11 · 选择与指标")
    }
}

// MARK: - Checkbox

private struct CheckboxSection: View {
    @State private var isSelected = false
    @State private var tone: SBTone = .primary

    var body: some View {
        Section("Checkbox（复选框）") {
            Text("教学点：点按只上报 .tapped，是否选中由业务决定并回写 —— 视图绝不就地翻转自己的状态。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            BridgeHost(
                state: CheckboxState(title: "同意《用户协议》",
                                     isSelected: isSelected,
                                     tone: tone,
                                     isEnabled: true),
                makeView: { CheckboxBridgeView() },
                onIntent: { intent in
                    if case .tapped = intent { isSelected.toggle() }
                }
            )
            .frame(height: 44)
            .listRowInsets(EdgeInsets())

            Toggle("选中", isOn: $isSelected)
            Picker("色调", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)
        }
    }
}

// MARK: - RadioGroup

private struct RadioGroupSection: View {
    @State private var selectedID: String?
    @State private var tone: SBTone = .primary

    private let options: [RadioOption] = [
        .init(id: "wechat", title: "微信支付"),
        .init(id: "alipay", title: "支付宝"),
        .init(id: "card", title: "银行卡"),
    ]

    var body: some View {
        Section("RadioGroup（单选组）") {
            Text("教学点：选项集合变化重建整组行；selectedID 变化只刷图标与读屏 value，不重建行。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            BridgeHost(
                state: RadioGroupState(options: options,
                                       selectedID: selectedID,
                                       tone: tone,
                                       isEnabled: true),
                makeView: { RadioGroupBridgeView() },
                onIntent: { intent in
                    if case .changed(let id) = intent { selectedID = id }
                }
            )
            .frame(height: 40 * CGFloat(options.count))
            .listRowInsets(EdgeInsets())

            Button("清空选择") { selectedID = nil }
            Picker("色调", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            LabeledContent("当前选中", value: selectedID ?? "—")
        }
    }
}

// MARK: - StepIndicator

private struct StepIndicatorSection: View {
    @State private var currentIndex = 1
    @State private var tone: SBTone = .primary

    private let steps = ["填写", "确认", "支付", "完成"]

    var body: some View {
        Section("StepIndicator（步骤指示器）") {
            Text("教学点：绘制型展示组件（NoIntent）—— 勾 ✓ / 当前步 / 未来步 + 完成段连线，全部在 draw 里画。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            BridgeHost(
                state: StepIndicatorState(steps: steps,
                                          currentIndex: currentIndex,
                                          tone: tone),
                makeView: { StepIndicatorBridgeView() },
                onIntent: { _ in }
            )
            .frame(height: 56)
            .listRowInsets(EdgeInsets())

            Stepper("当前第 \(currentIndex + 1) 步：\(steps[currentIndex])",
                    value: $currentIndex, in: 0...steps.count - 1)
            Picker("色调", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)
        }
    }
}

// MARK: - Sparkline

private struct SparklineSection: View {
    @State private var points = DemoSparkline.sample
    @State private var showsFill = true
    @State private var tone: SBTone = .primary

    var body: some View {
        Section("Sparkline（迷你趋势图）") {
            Text("教学点：绘制型展示组件（NoIntent）—— 纵坐标按 min/max 归一化到画布，序列长短自适应；单点画圆点、全等值画中线。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            BridgeHost(
                state: SparklineState(points: points,
                                      tone: tone,
                                      showsFill: showsFill),
                makeView: { SparklineBridgeView() },
                onIntent: { _ in }
            )
            .frame(height: 56)
            .listRowInsets(EdgeInsets())

            Button("重新生成趋势") { points = DemoSparkline.sample }
            Toggle("填充带", isOn: $showsFill)
            Picker("色调", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)
        }
    }
}

/// 生成一组 24 点的心跳状趋势数据（Demo 内私用，无状态）。
private struct DemoSparkline {
    static var sample: [Double] {
        (0..<24).map { step in
            let wave = sin(Double(step) / 3)
            let noise = Double.random(in: -0.25...0.25)
            return (wave + noise) / 2 + 0.5
        }
    }
}

#Preview {
    NavigationStack {
        Demo11_SelectionMetricsGalleryPage()
    }
}
