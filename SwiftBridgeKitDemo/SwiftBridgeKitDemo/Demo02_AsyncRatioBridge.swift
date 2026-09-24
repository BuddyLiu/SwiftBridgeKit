//
//  Demo02_AspectRatioBridge.swift
//  SwiftBridgeKitDemo
//
//  Demo 02：异步比例 → 布局回流（设施三的运行时验证）
//
//  这个 Demo 验证「最难的那半程」：
//    视图已上屏 → 网络/解码完成 → 才知道真实宽高比 → 必须主动请求一次重布局
//
//  链路（组件作者只写前两跳，后两跳是框架兜线）：
//    组件拿到比例 → resolver.resolve()（值比较早退）
//      → view.onRequestLayout?()         （Coordinator 在 attach 时注入）
//        → coordinator.onRequestLayout  （BridgeRepresentable.makeUIView 兜线）
//          → BridgeHost @State 令牌 +1   → SwiftUI 重新布局
//            → sizeThatFits 用新比例算高度
//
//  自检方式（控制台）：
//    1. 进入页面打印「开始加载」→ 0.8s 后打印「比例已就绪」。
//    2. 接着会打印一次「sizeThatFits 读到新比例」—— 这就是回流生效的证据。
//    3. 静置后不再有任何打印（没有循环更新）。
//    4. 反复点「重新加载」，高度每次从占位 72pt 跳到「宽度÷比例」。
//

import SwiftUI
import UIKit
import SwiftBridgeKit
import SwiftChainKit
import SnapKit

// MARK: - 契约层（纯 Swift）

/// 数据：SwiftUI → 桥（单向流入）
/// loadID 每次 +1 表示「重新换一张图」，targetRatio 是这张图的目标宽高比。
struct AspectState: BridgeState {
    var loadID: Int
    var targetRatio: CGFloat
}

// MARK: - 桥视图（组件作者唯一需要写的东西）

final class AspectRatioView: UIView, BridgeView, RatioAwareBridge {

    typealias State = AspectState
    typealias Intent = NoIntent

    var onIntent: ((NoIntent) -> Void)?
    var onRequestLayout: (() -> Void)?   // 回流通道，Coordinator 在 attach 时注入

    /// 内容宽高比（宽/高）。nil = 尚未就绪，SwiftUI 侧不参与布局。
    var contentRatio: CGFloat?

    private let resolver = RatioResolver()
    /// Lazy 属性声明处链式创建：四步配置收进一条链。
    private let label = UILabel().chain()
        .textAlignment(.center)
        .numberOfLines(0)
        .font(.systemFont(ofSize: 13))
        .textColor(.secondaryLabel)
        .build()
    private var lastLoadID = -1

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemGray6
        layer.cornerRadius = 10

        addSubview(label)
        // 替代 layoutSubviews 里的 `label.frame = bounds`：约束随自身 bounds 自动跟随
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        wireResolver()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 比例未知时的占位高度（sizeThatFits 返回 nil 时由 SwiftUI 用 intrinsic 兜底）
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 72)
    }

    // MARK: - BridgeView

    func apply(_ state: AspectState) {
        guard state.loadID != lastLoadID else { return }
        lastLoadID = state.loadID

        // 旧比例作废 → 高度先回落到占位档
        contentRatio = nil
        resolver.reset()          // 清掉旧值：否则同一比例复用时会因「值比较早退」不再回流
        wireResolver()
        label.text = "加载中…（目标比例 \(Self.fmt(state.targetRatio))）\n当前高度：占位 72pt"
        print("[AspectDemo] 开始加载 targetRatio=\(Self.fmt(state.targetRatio))")

        // 模拟「网络/解码完成后才知道真实比例」
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            self.contentRatio = state.targetRatio
            self.resolver.resolve(state.targetRatio)   // 值比较早退 + 请求一次布局回流
            self.label.text = "比例已就绪：\(Self.fmt(state.targetRatio))\n高度 = 宽度 ÷ 比例（回流触发的重新布局）"
            print("[AspectDemo] 比例已就绪 ratio=\(Self.fmt(state.targetRatio))")
        }
    }

    func teardown() {
        onIntent = nil
        onRequestLayout = nil
    }

    // MARK: - 私有

    private func wireResolver() {
        resolver.onRequestLayout = { [weak self] in
            self?.onRequestLayout?()
        }
    }

    private static func fmt(_ value: CGFloat) -> String {
        String(format: "%.2f", value)
    }
}

// MARK: - 观测：只在比例变化时打印一次

private final class RatioLog {
    private var lastLogged: CGFloat?
    func logChange(_ ratio: CGFloat?) {
        guard let ratio, lastLogged != ratio else { return }
        lastLogged = ratio
        print("[AspectDemo] sizeThatFits 读到新比例 \(String(format: "%.2f", ratio)) → 回流生效")
    }
}

// MARK: - Demo 页面（业务侧：只依赖 BridgeHost + 契约）

struct Demo02_AsyncRatioBridgePage: View {

    private let ratios: [CGFloat] = [16/9, 4/3, 1.0, 3/4]

    @State private var loadID = 0
    @State private var targetRatio: CGFloat = 16/9
    @State private var log = RatioLog()

    var body: some View {
        List {
            Section("桥组件（异步比例 → 布局回流）") {
                BridgeHost(
                    state: AspectState(loadID: loadID, targetRatio: targetRatio),
                    makeView: { AspectRatioView() },
                    onIntent: { _ in },
                    ratioProvider: { view in
                        // Demo 观测：布局期读到的新比例，即 sizeThatFits 正在用的值
                        log.logChange(view.contentRatio)
                        return view.contentRatio
                    }
                )
                .id(loadID)   // ⚠️ 换一次 id 彻底重建视图 = 模拟「换了张图」，这是 Demo 的触发方式
                .padding(.vertical, 6)
                .listRowInsets(EdgeInsets())
            }

            Section("控制") {
                Button("重新加载（换一个宽高比）") {
                    targetRatio = ratios.randomElement()!
                    loadID += 1
                }
                LabeledContent("当前目标比例", value: String(format: "%.2f", targetRatio))
                Text("观察卡片高度：点「重新加载」后，从占位 72pt 跳到「宽度÷比例」——说明异步比例的布局回流已生效。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("02 · 异步比例回流")
    }
}

#Preview {
    NavigationStack {
        Demo02_AsyncRatioBridgePage()
    }
}