//
//  Demo07_ComponentsGallery.swift
//  SwiftBridgeKitDemo
//
//  Demo 07：组件库（SwiftBridgeComponents）
//
//  五个开箱即用组件各占一节：BridgeHost 渲染 UIKit 视图，
//  下方控制区用 Picker / Toggle / Slider 热切换契约枚举 ——
//  每次切换都走「值比较早退 → 差异映射」，不做全量重建。
//
//  ⚠️ 组件包的枚举名与 SwiftUI 自带类型撞名（ButtonStyle / BadgeShape / AvatarShape），
//     本页用 `SB*` 别名统一指向组件包的版式枚举，避免同文件内歧义。
//
//  自检方式：
//    1. 切换各 Picker / Toggle，视觉应即时跟随、无闪烁。
//    2. TextField 区点「外部注入」：正在编辑时光标不被打断。
//    3. Button 区开「加载中」：显示菊花、按钮强制禁用。
//    4. 页面静置时控制台不应有组件打印。
//

import SwiftUI
import UIKit
import SwiftBridgeKit
import SwiftBridgeComponents

// MARK: - 组件枚举别名（消歧）

private typealias SBButtonStyle = SwiftBridgeComponents.ButtonStyle
private typealias SBButtonSize = SwiftBridgeComponents.ButtonSize
private typealias SBButtonIconPosition = SwiftBridgeComponents.ButtonIconPosition
private typealias SBBadgeShape = SwiftBridgeComponents.BadgeShape
private typealias SBAvatarShape = SwiftBridgeComponents.AvatarShape
private typealias SBTextFieldBorder = SwiftBridgeComponents.TextFieldBorder
private typealias SBKeyboardKind = SwiftBridgeComponents.KeyboardKind
private typealias SBTone = SwiftBridgeComponents.ComponentTone
private typealias SBStarTone = SwiftBridgeComponents.RatingStarTone

struct Demo07_ComponentsGalleryPage: View {

    var body: some View {
        List {
            // 组件库页按使用频率排序：表单控件前置
            SwitchSection()
            SegmentedSection()
            SliderSection()
            ButtonSection()
            ChipSection()
            TextFieldSection()
            BadgeSection()
            AvatarSection()
            RatingSection()
            NoticeSection()
            EmptyStateSection()

            Section("自检清单") {
                Text("· 枚举 Picker 热切换 → 视图即时更新（差异映射）")
                Text("· TextField 输入时点「外部注入」→ 光标不被打断")
                Text("· Button「加载中」→ 菊花 + 强制禁用")
                Text("· Switch/Segmented/Slider 拖拽时外部注入不打断手势")
                Text("· Chip 点击上报、选中态由业务回写")
                Text("· Notice/EmptyState 按钮只上报意图，显示与否由业务管")
                Text("· 静置时控制台无组件日志")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("07 · 组件库")
    }
}

// MARK: - Button

private struct ButtonSection: View {
    @State private var style: SBButtonStyle = .primary
    @State private var size: SBButtonSize = .regular
    @State private var title = "立即加入"
    @State private var iconPosition: SBButtonIconPosition = .leading
    @State private var isLoading = false
    @State private var isEnabled = true
    @State private var loadingTitle: String?
    @State private var lastTap = 0

    var body: some View {
        Section("Button") {
            BridgeHost(
                state: ButtonState(
                    title: title,
                    style: style,
                    size: size,
                    icon: "bolt.fill",
                    iconPosition: iconPosition,
                    isEnabled: isEnabled,
                    isLoading: isLoading,
                    loadingTitle: loadingTitle
                ),
                makeView: { ButtonBridgeView() },
                onIntent: { _ in lastTap += 1 }
            )
            .listRowInsets(EdgeInsets())

            Picker("样式", selection: $style) {
                ForEach(SBButtonStyle.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Picker("尺寸", selection: $size) {
                ForEach(SBButtonSize.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.segmented)

            Picker("图标位置", selection: $iconPosition) {
                ForEach(SBButtonIconPosition.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.segmented)

            LabeledContent("点击次数", value: "\(lastTap)")
            Toggle("可用", isOn: $isEnabled)
            Toggle("加载中", isOn: $isLoading)
            Toggle("加载文案：提交中…", isOn: Binding(
                get: { loadingTitle != nil },
                set: { loadingTitle = $0 ? "提交中…" : nil }
            ))
        }
    }
}

// MARK: - Badge

private struct BadgeSection: View {
    @State private var text = "128"
    @State private var tone: SBTone = .primary
    @State private var shape: SBBadgeShape = .round
    @State private var showsDot = true
    @State private var showsMax = true

    var body: some View {
        Section("Badge") {
            // HStack 包裹：List 全宽 row 会被 proposal 拉宽，字多时保持 compact
            HStack {
                Spacer(minLength: 0)
                BridgeHost(
                    state: BadgeState(text: text, maxValue: showsMax ? 99 : nil, tone: tone, shape: shape, showsDot: showsDot),
                    makeView: { BadgeBridgeView() },
                    onIntent: { _ in }
                )
                Spacer(minLength: 0)
            }
            .listRowInsets(EdgeInsets())

            TextField("输入数字或文案", text: $text)

            Picker("色调", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Picker("形态", selection: $shape) {
                ForEach(SBBadgeShape.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.segmented)

            Toggle("右上角圆点", isOn: $showsDot)
            Toggle("溢出上限 99（超了 → 99+）", isOn: $showsMax)
        }
    }
}

// MARK: - TextField

private struct TextFieldSection: View {
    @State private var text = ""
    @State private var border: SBTextFieldBorder = .roundedRect
    @State private var keyboard: SBKeyboardKind = .standard
    @State private var isSecure = false
    @State private var maxLength: Int?
    @State private var lastSubmitted = "—"

    var body: some View {
        Section("TextField") {
            BridgeHost(
                state: SwiftBridgeComponents.TextFieldState(
                    text: text,
                    placeholder: "输入昵称…",
                    placeholderTone: .neutral,
                    keyboard: keyboard,
                    leadingIcon: "person.fill",
                    border: border,
                    isSecure: isSecure,
                    maxLength: maxLength
                ),
                // ⚠️ Demo03 在本模块里也定义了 TextFieldBridgeView（教学内联版），
                //    同模块声明遮蔽 import，必须模块限定指到组件包版本。
                makeView: { SwiftBridgeComponents.TextFieldBridgeView() },
                onIntent: { intent in
                    switch intent {
                    case .textChanged(let value): text = value
                    case .submitted: lastSubmitted = text
                    }
                }
            )
            .listRowInsets(EdgeInsets())

            Button("外部注入：改为「已注入的值」") {
                // ⚠️ 输入保护验证：正在编辑时注入，TextField 不抢光标
                text = "已注入的值"
            }

            Picker("边框", selection: $border) {
                ForEach(SBTextFieldBorder.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.segmented)

            Picker("键盘", selection: $keyboard) {
                ForEach(SBKeyboardKind.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Toggle("密码", isOn: $isSecure)
            Stepper("最大长度：\(maxLength.map(String.init) ?? "不限")", value: Binding(
                get: { maxLength ?? 0 },
                set: { maxLength = $0 == 0 ? nil : $0 }
            ), in: 0...12)

            LabeledContent("最近提交", value: lastSubmitted)
        }
    }
}

// MARK: - Avatar

private struct AvatarSection: View {
    @State private var shape: SBAvatarShape = .circular
    @State private var dimension: CGFloat = 56
    @State private var borderWidth: CGFloat = 2
    @State private var borderTone: SBTone = .primary
    @State private var hasImage = false
    @State private var showsStatusDot = true

    var body: some View {
        Section("Avatar") {
            HStack {
                Spacer(minLength: 0)
                BridgeHost(
                    state: AvatarState(
                        title: "林晓",
                        image: hasImage ? Self.demoImage : nil,
                        shape: shape,
                        dimension: dimension,
                        borderWidth: borderWidth,
                        borderTone: borderTone,
                        showsStatusDot: showsStatusDot
                    ),
                    makeView: { AvatarBridgeView() },
                    onIntent: { _ in }
                )
                Spacer(minLength: 0)
            }
            .listRowInsets(EdgeInsets())

            Picker("形态", selection: $shape) {
                ForEach(SBAvatarShape.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.segmented)

            Toggle("显示图片", isOn: $hasImage)
            Toggle("在线状态点", isOn: $showsStatusDot)
            Slider(value: $dimension, in: 32...96, step: 4) {
                Text("尺寸")
            }
            LabeledContent("尺寸", value: "\(Int(dimension))pt")

            Picker("边框色调", selection: $borderTone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)
        }
    }

    /// 演示用占位图：橙底白色「图」字。
    private static let demoImage: UIImage = {
        let size = CGSize(width: 96, height: 96)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemOrange.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            UIColor.white.setFill()
            let text = "图" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 36),
                .foregroundColor: UIColor.white,
            ]
            let ts = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: (size.width - ts.width) / 2, y: (size.height - ts.height) / 2), withAttributes: attrs)
        }
    }()
}

// MARK: - Rating

private struct RatingSection: View {
    @State private var rating: Double = 3.5
    @State private var starTone: SBStarTone = .gold
    @State private var allowsHalfSteps = true
    @State private var isEnabled = true

    var body: some View {
        Section("Rating") {
            BridgeHost(
                state: RatingState(
                    rating: rating,
                    starCount: 5,
                    isEnabled: isEnabled,
                    starTone: starTone,
                    allowsHalfSteps: allowsHalfSteps
                ),
                makeView: { RatingBridgeView() },
                onIntent: { intent in
                    switch intent {
                    case .changed(let value): rating = value
                    }
                }
            )
            .frame(height: 44)
            .padding(.vertical, 6)
            .listRowInsets(EdgeInsets())

            Slider(value: $rating, in: 0...5, step: 0.5)
            Picker("星色", selection: $starTone) {
                ForEach(SBStarTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Toggle("半星步进", isOn: $allowsHalfSteps)
            Toggle("可用", isOn: $isEnabled)
        }
    }
}

// MARK: - Switch

private struct SwitchSection: View {
    @State private var isOn = true
    @State private var tone: SBTone = .primary
    @State private var isEnabled = true
    @State private var lastIntent = "—"

    var body: some View {
        Section("Switch") {
            BridgeHost(
                state: SwitchState(isOn: isOn, tone: tone, isEnabled: isEnabled),
                makeView: { SwitchBridgeView() },
                onIntent: { intent in
                    switch intent {
                    case .changed(let value):
                        isOn = value
                        lastIntent = "changed(\(value))"
                    }
                }
            )
            .listRowInsets(EdgeInsets())

            // SwiftUI → 桥（下行）：外面 Toggle 改 @State，UISwitch 跟着变
            Toggle("开", isOn: $isOn)
            Picker("色调", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Toggle("可用", isOn: $isEnabled)
            LabeledContent("最近意图", value: lastIntent)
        }
    }
}

// MARK: - Segmented

private struct SegmentedSection: View {
    @State private var items = ["周", "月", "年"]
    @State private var selectedIndex = 1
    @State private var tone: SBTone = .primary
    @State private var isEnabled = true
    @State private var isMomentary = false

    var body: some View {
        Section("Segmented") {
            BridgeHost(
                state: SegmentedState(items: items, selectedIndex: selectedIndex, tone: tone, isEnabled: isEnabled, isMomentary: isMomentary),
                makeView: { SegmentedBridgeView() },
                onIntent: { intent in
                    switch intent {
                    case .changed(let index): selectedIndex = index
                    }
                }
            )
            .listRowInsets(EdgeInsets())

            Picker("色调", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Toggle("瞬时（当了按钮，松手即清选）", isOn: $isMomentary)
            Toggle("可用", isOn: $isEnabled)
            LabeledContent("选中段", value: items.indices.contains(selectedIndex) ? items[selectedIndex] : "—")
            Button("外部注入：选第 0 项") { selectedIndex = 0 }
        }
    }
}

// MARK: - Slider

private struct SliderSection: View {
    @State private var value: Double = 0.4
    @State private var step: Double = 0.05
    @State private var tone: SBTone = .primary
    @State private var isEnabled = true
    @State private var reportsContinuously = true

    var body: some View {
        Section("Slider") {
            BridgeHost(
                state: SliderState(value: value, min: 0, max: 1, step: step, tone: tone, isEnabled: isEnabled, reportsContinuously: reportsContinuously),
                makeView: { SliderBridgeView() },
                onIntent: { intent in
                    switch intent {
                    case .changed(let v): value = v
                    }
                }
            )
            .listRowInsets(EdgeInsets())

            Picker("色调", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Toggle("step = 0.05 取整", isOn: Binding(
                get: { step > 0 },
                set: { step = $0 ? 0.05 : 0 }
            ))
            Toggle("拖拽中实时上报", isOn: $reportsContinuously)
            Toggle("可用", isOn: $isEnabled)
            LabeledContent("当前值", value: String(format: "%.2f", value))
        }
    }
}

// MARK: - Chip

private struct ChipSection: View {
    private let items = ["全部", "进行中", "已完成", "已逾期"]
    @State private var selectedIndex = 0
    @State private var tone: SBTone = .primary
    @State private var showsIcon = true
    @State private var showsCheckmark = true

    var body: some View {
        Section("Chip") {
            // 横向滚动一排标签，选中态由业务回写
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items.indices, id: \.self) { i in
                        BridgeHost(
                            state: ChipState(title: items[i], tone: tone, isSelected: i == selectedIndex, icon: showsIcon ? "tag.fill" : nil, showsCheckmark: showsCheckmark),
                            makeView: { ChipBridgeView() },
                            onIntent: { _ in selectedIndex = i }
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowInsets(EdgeInsets())

            Picker("色调", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Toggle("显示图标", isOn: $showsIcon)
            Toggle("选中打勾", isOn: $showsCheckmark)
            LabeledContent("选中", value: items[selectedIndex])
        }
    }
}

// MARK: - Notice

private struct NoticeSection: View {
    @State private var tone: SBTone = .success
    @State private var showsClose = true
    @State private var message: String? = "这是可选的副文案，适合放更长一点的说明。"
    @State private var autoDismiss = false
    @State private var dismissCount = 0

    var body: some View {
        Section("Notice") {
            if showsClose {
                BridgeHost(
                    state: NoticeState(
                        title: "保存成功",
                        message: message,
                        tone: tone,
                        icon: nil,
                        showsClose: true,
                        autoDismissAfter: autoDismiss ? 3 : nil
                    ),
                    makeView: { NoticeBridgeView() },
                    onIntent: { intent in
                        switch intent {
                        case .close: showsClose = false   // 业务决定收起
                        case .autoDismissed:
                            showsClose = false            // 自动消失同样由业务收起
                            dismissCount += 1
                        }
                    }
                )
                .listRowInsets(EdgeInsets())
            }

            Picker("色调", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Toggle("显示副文案", isOn: Binding(
                get: { message != nil },
                set: { message = $0 ? "这是可选的副文案，适合放更长一点的说明。" : nil }
            ))
            Toggle("3 秒自动消失", isOn: $autoDismiss)
            LabeledContent("自动消失次数", value: "\(dismissCount)")
            Button("重新弹出", action: { showsClose = true })
        }
    }
}

// MARK: - EmptyState

private struct EmptyStateSection: View {
    @State private var tone: SBTone = .primary
    @State private var actionTitle: String? = "去逛逛"
    @State private var secondaryActionTitle: String?
    @State private var actionCount = 0
    @State private var secondaryCount = 0

    var body: some View {
        Section("EmptyState") {
            BridgeHost(
                state: EmptyStateState(
                    title: "还没有内容",
                    message: "去创建第一条记录吧，页面空着也没关系",
                    icon: "tray",
                    actionTitle: actionTitle,
                    secondaryActionTitle: secondaryActionTitle,
                    tone: tone
                ),
                makeView: { EmptyStateBridgeView() },
                onIntent: { intent in
                    switch intent {
                    case .actionTapped: actionCount += 1          // 只计数，显示与否由业务管
                    case .secondaryActionTapped: secondaryCount += 1
                    }
                }
            )
            .listRowInsets(EdgeInsets())

            Picker("色调", selection: $tone) {
                ForEach(SBTone.allCases, id: \.self) { Text(verbatim: "\($0)") }
            }
            .pickerStyle(.menu)

            Toggle("显示按钮", isOn: Binding(
                get: { actionTitle != nil },
                set: { actionTitle = $0 ? "去逛逛" : nil }
            ))
            Toggle("次级按钮", isOn: Binding(
                get: { secondaryActionTitle != nil },
                set: { secondaryActionTitle = $0 ? "稍后再说" : nil }
            ))
            LabeledContent("主按钮点击次数", value: "\(actionCount)")
            LabeledContent("次级点击次数", value: "\(secondaryCount)")
        }
    }
}

#Preview {
    NavigationStack {
        Demo07_ComponentsGalleryPage()
    }
}