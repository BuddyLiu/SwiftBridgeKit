//
//  Demo01_RatingBridge.swift
//  SwiftBridgeKitDemo
//
//  Demo 01：最小闭环
//
//  这个 Demo 演示桥的核心链路，不涉及复杂能力：
//    · 契约层  —— RatingState / RatingIntent，纯值枚举
//    · 状态下行 —— SwiftUI 是唯一真相，桥只做「差异映射」
//    · 意图上行 —— 手势 → Intent → 业务，桥不自己改数据
//    · 更新抑制 —— 上下行不会互相触发循环
//
//  评分组件本体已收编进 `SwiftBridgeComponents`（RatingComponent.swift）：
//  这里直接 `import SwiftBridgeComponents` 使用 `RatingState` / `RatingBridgeView`，
//  `BridgeHost` 仍在框架包 `SwiftBridgeKit`。
//
//  自检方式：
//    1. 打开后静置 —— 拖动 Slider 松手后，星星不回跳、数值稳定。
//       若视觉在来回抖动，说明存在循环更新（本 Demo 不应出现）。
//    2. 拖动/点按星星，观察「最近意图」刷新，且不会出现抖动/弹回。
//

import SwiftUI
import SwiftBridgeKit
import SwiftBridgeComponents

// MARK: - Demo 页面（业务侧：只依赖 BridgeHost + 契约）

struct Demo01_RatingBridgePage: View {

    private let starCount = 5

    @State private var rating: Double = 2.5
    @State private var isEnabled = true
    @State private var lastIntent = "—"

    var body: some View {
        List {
            Section("桥组件") {
                BridgeHost(
                    state: RatingState(rating: rating, starCount: starCount, isEnabled: isEnabled),
                    makeView: { RatingBridgeView() },
                    onIntent: { intent in
                        switch intent {
                        case .changed(let value):
                            rating = value          // ✅ 业务是唯一真相，回写后再下行给桥
                            lastIntent = "changed(\(value))"
                        }
                    }
                )
                .frame(height: 44)
                .padding(.vertical, 6)
                .listRowInsets(EdgeInsets())
            }

            Section("SwiftUI → 桥（下行）") {
                Slider(value: $rating, in: 0...Double(starCount), step: 0.5)
                Toggle("可用", isOn: $isEnabled)
            }

            Section("桥 → 业务（上行）") {
                LabeledContent("当前值", value: String(format: "%.1f", rating))
                LabeledContent("最近意图", value: lastIntent)
            }

            Section("这个 Demo 在验证什么") {
                Text("· 状态下行：拖动 Slider，UIKit 视图跟着变（说明 apply 生效）")
                Text("· 意图上行：点/拖星星，SwiftUI 侧数值跟着变（说明 Intent 生效）")
                Text("· 更新抑制：静置时视图不回跳，上下行不互相触发循环")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .navigationTitle("01 · 最小闭环")
    }
}

#Preview {
    NavigationStack {
        Demo01_RatingBridgePage()
    }
}