//
//  Demo04_ScrollBridge.swift
//  SwiftBridgeKitDemo
//
//  Demo 04：可滚动容器 —— UIScrollView
//
//  这一类视图的坑：
//    1. **offset 上报风暴**：滚动每一帧都在变，不能每帧都 onIntent。
//       要在上报侧「按值去重 + 取整」再上报（差异映射的反向应用）。
//    2. **程序化滚动会再次触发 scrollViewDidScroll**：
//       SwiftUI 命令「滚到 X」 → apply 里 setContentOffset → 又上报 X
//       → SwiftUI state 又回到 X → 只要值没变，链路就会自收敛。
//       但要在 apply 里用标志位压制自己引发的上报，否则会空转一圈。
//    3. **delegate 断连**：teardown 里必须 delegate = nil。
//
//  这个 demo 刻意不用 KVO 观察 contentOffset（KVO 的 removeObserver 幂等问题
//  更容易踩）；用 UIScrollViewDelegate.scrollViewDidScroll 一样能拿到 offset，
//  且断连只需 delegate = nil，更符合本包「生命周期收口」的教导。
//

import SwiftUI
import UIKit
import SwiftBridgeKit
import SwiftChainKit
import SnapKit

// MARK: - 契约层

struct ScrollState: BridgeState {
    var contentHeight: CGFloat    // 内容高度（变化时改 contentSize）
    var targetOffset: CGPoint     // 命令式滚动目标（变化时才执行）
    var isScrollEnabled: Bool
}

enum ScrollIntent: BridgeIntent {
    case offsetChanged(CGPoint)
}

// MARK: - 桥视图（直接就是 UIScrollView 子类 —— 容器视图也可以当叶视图）

final class ScrollBridgeView: UIScrollView, BridgeView, UIScrollViewDelegate {

    typealias State = ScrollState
    typealias Intent = ScrollIntent

    var onIntent: ((ScrollIntent) -> Void)?

    /// apply 等值比较用的「已执行过的滚动命令」。
    private var lastExecutedTarget = CGPoint(x: -1, y: -1)
    /// 去重上报用的「已上报过的 offset」。
    private var lastReported = CGPoint(x: -1, y: -1)
    /// 压制「程序化滚动引发的上报」。
    private var isProgrammaticScroll = false
    private(set) var applyCount = 0

    /// 内容容器 + 色块列表。宽度经约束固定为滚动区实际宽度（见 init 注释）。
    private let content = UIView()
    private var blocks: [UIView] = []
    /// 内容高度约束：apply 里 update 它来驱动 contentSize，替代直接改 contentSize
    private var contentHeightConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        alwaysBounceVertical = true
        showsVerticalScrollIndicator = true
        backgroundColor = .systemGray6
        layer.cornerRadius = 8

        // 内容宽度的正解：用约束直接把 content 宽贴在滚动区宽上，
        // 再让色块 leading/trailing 相对 content 各留 12 ——
        // 右边缘 = W−12 < W，永远贴在容器内，bounds 变化自动跟随（无需 layoutSubviews）。
        // 高：只 pin top/leading（不 pin bottom），contentSize 才会被内容撑到 H。
        content.chain()
            .added(to: self)
            .build()
        content.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.width.equalToSuperview()
            contentHeightConstraint = make.height.equalTo(600).constraint
        }

        // 8 个色块：链式创建 + 从上往下叠（首块 top 相对 content，后续相对上一块 bottom）
        for index in 0..<8 {
            let block = UIView().chain()
                .backgroundColor(UIColor(hue: CGFloat(index) / 9, saturation: 0.35, brightness: 0.9, alpha: 1))
                .cornerRadius(8)
                .added(to: content)
                .build()
            block.snp.makeConstraints { make in
                if let last = blocks.last {
                    make.top.equalTo(last.snp.bottom).offset(12)
                } else {
                    make.top.equalTo(content).offset(12)
                }
                make.leading.equalTo(content).offset(12)
                make.trailing.equalTo(content).offset(-12)
                make.height.equalTo(56)
            }
            blocks.append(block)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 260)
    }

    // MARK: - BridgeView

    func apply(_ state: ScrollState) {
        applyCount += 1

        // 差异映射：内容尺寸（改高度约束 → 布局后 contentSize 随之更新）
        if contentSize.height != state.contentHeight {
            contentHeightConstraint?.update(offset: state.contentHeight)
            print("[ScrollDemo] contentSize → \(Int(state.contentHeight))")
        }
        if isScrollEnabled != state.isScrollEnabled { isScrollEnabled = state.isScrollEnabled }

        // 命令式滚动：只执行「新命令」；执行时压制自己的上报
        let target = state.targetOffset
        if abs(target.x - lastExecutedTarget.x) > 1 || abs(target.y - lastExecutedTarget.y) > 1 {
            lastExecutedTarget = target
            isProgrammaticScroll = true
            contentOffset = target
            isProgrammaticScroll = false
            lastReported = target
            print("[ScrollDemo] 程序化滚动 → \(Self.fmt(target))")
        }
    }

    func teardown() {
        delegate = nil
        onIntent = nil
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isProgrammaticScroll else { return }

        // 按值去重 + 取整到 1pt，避免每帧上报
        let offset = scrollView.contentOffset
        let rounded = CGPoint(x: (offset.x * 4).rounded() / 4, y: (offset.y * 4).rounded() / 4)
        guard round(rounded.x - lastReported.x) != 0 || round(rounded.y - lastReported.y) != 0 else { return }
        lastReported = rounded
        print("[ScrollDemo] 用户滚动 offset=\(Self.fmt(rounded))")
        onIntent?(.offsetChanged(rounded))
    }

    private static func fmt(_ p: CGPoint) -> String {
        "(\(Int(p.x)), \(Int(p.y)))"
    }
}

// MARK: - Demo 页面

struct Demo04_ScrollBridgePage: View {

    @State private var contentHeight: CGFloat = 600
    @State private var targetOffset: CGPoint = .zero
    @State private var isScrollEnabled = true
    @State private var currentOffsetY: CGFloat = 0

    var body: some View {
        List {
            Section("UIScrollView（offset 上报 + 命令式滚动）") {
                BridgeHost(
                    state: ScrollState(contentHeight: contentHeight, targetOffset: targetOffset, isScrollEnabled: isScrollEnabled),
                    makeView: { ScrollBridgeView() },
                    onIntent: { intent in
                        if case .offsetChanged(let p) = intent { currentOffsetY = p.y }
                    }
                )
                .frame(height: 260)
                .listRowInsets(EdgeInsets())
            }

            Section("控制") {
                Button("滚到顶部（0, 0）") { targetOffset = .zero }
                Button("滚到中部（0, 300）") { targetOffset = CGPoint(x: 0, y: 300) }
                Button("内容加高到 1200") { contentHeight = 1200 }
                Button("内容恢复 600") { contentHeight = 600 }
                Toggle("允许滚动", isOn: $isScrollEnabled)
                LabeledContent("当前 offsetY", value: "\(Int(currentOffsetY))")
                Text("自检：手动上下滑 → 控制台出现「用户滚动」且不打满帧；点「滚到中部」→ 程序化滚动待一次到位，随后不再有滚动日志（自收敛）。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("04 · 可滚动容器（ScrollView）")
    }
}

#Preview {
    NavigationStack { Demo04_ScrollBridgePage() }
}