//
//  IndexBarComponent.swift
//  SwiftBridgeComponents
//
//  字母索引条 —— 容器/导航组件：右侧 A–Z 竖排索引，拖动高亮并上报（无原生控件，自绘）。
//
//  教学点：
//    1. **热区换算做纯函数**：`IndexBarGeometry.index(forY:height:count:)` 把触摸 y
//       映射到条目下标并钳界，无 UIKit 依赖 → 可单测（越界、空数据、单条）。
//    2. **无手势识别器也能拖**：直接 override `touchesBegan/Moved` 读 touch 的 y，
//       teardown 干净（没有识别器可摘）；isEnabled 切换即关交互。
//    3. **相对拖动连续但要按 index 去重**：touchesMoved 频繁回调，只有跨字母才上报，
//       并配一次轻震触感反馈。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    items      → 重建 label 栈 + invalidateIntrinsicContentSize（高度跟随外部传入）
//    tone / activeTone → 常态字色 / 拖动高亮字色
//    isEnabled  → isUserInteractionEnabled + 整体降透明度
//  touches 里 index 变化才上报 .changed(当前字母)，touchesEnded 清除高亮、保留最近上报。
//

import UIKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 纯函数几何（可单测）

/// 索引条热区换算：触摸 y 坐标 → 条目下标。
public enum IndexBarGeometry {
    /// 把 `y` 映射到条目下标并钳到首尾；`count <= 0` 或 `height <= 0` 返回 nil。
    /// - Parameters:
    ///   - y: 触摸点在条内的 y 坐标。
    ///   - height: 条的总高。
    ///   - count: 条目数。
    public static func index(forY y: CGFloat, height: CGFloat, count: Int) -> Int? {
        guard count > 0, height > 0 else { return nil }
        let clamped = min(max(y, 0), height)
        let raw = clamped / height * CGFloat(count)
        return min(Int(raw), count - 1)
    }
}

// MARK: - 契约层

/// 字母索引条的展示状态：条目 + 常态/高亮双色调 + 可用性。
public struct IndexBarState: BridgeState {
    /// 索引条目（默认 A–Z）。
    public var items: [String]
    /// 常态字色。
    public var tone: ComponentTone
    /// 拖动高亮字色。
    public var activeTone: ComponentTone
    /// 是否可交互。
    public var isEnabled: Bool

    /// 构造字母索引条状态。
    /// - Parameters:
    ///   - items: 索引条目；默认 A–Z 26 个。
    ///   - tone: 常态字色；默认 .neutral。
    ///   - activeTone: 拖动高亮字色；默认 .primary。
    ///   - isEnabled: 是否可交互；默认 true。
    public init(items: [String] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init),
                tone: ComponentTone = .neutral,
                activeTone: ComponentTone = .primary,
                isEnabled: Bool = true) {
        self.items = items
        self.tone = tone
        self.activeTone = activeTone
        self.isEnabled = isEnabled
    }
}

/// 字母索引条交互意图：当前高亮条目变化（跨字母才上报）。
public enum IndexBarIntent: BridgeIntent {
    /// 拖动停在某个条目上时上报该条目；松手不额外上报。
    case changed(String)
}

// MARK: - 桥视图

/// 字母索引条桥视图：touches 直接驱动，热区换算走纯函数。
@MainActor
public final class IndexBarBridgeView: UIView, BridgeView {

    /// 桥状态类型：条目 + 双色调等。
    public typealias State = IndexBarState
    /// 桥意图类型：当前高亮条目。
    public typealias Intent = IndexBarIntent

    /// 意图上抛回调：当前高亮条目。
    public var onIntent: ((IndexBarIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）。nil = 回落全局 `ComponentTheme.current`。
    /// 必须有真实存储（不能用协议默认空实现）：否则 coordinator 下行 `view.theme = theme`
    /// 被丢弃，resolvedTheme() 永远读到 nil → 每桥 override 不生效（Rating 同款坑）。
    public var theme: (any BridgeTheme)?

    /// internal（非 private）：留给 @testable 冒烟测试校验 apply 重建 label 栈用。
    var itemLabels: [UILabel] { labels }
    private var labels: [UILabel] = []
    /// 当前条目（apply 随 items 刷新，驱动渲染与热区换算）。
    private var currentItems: [String] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init)
    /// 触感反馈：每次跨字母轻震一下。
    private let feedback = UIImpactFeedbackGenerator(style: .light)
    /// 当前高亮下标；nil = 未在拖动。
    private var highlightedIndex: Int?
    /// 上报去重水印：字母没变就不上报。
    private var lastReported: String?
    /// 读屏可调档的当前下标：与拖动高亮独立维护（增减一档后直接上报，不依赖呈现态收敛）。
    private var a11yIndex: Int = 0
    /// 上次生效主题：换肤重放 apply 时重染 label 栈。
    private var cachedTheme: ComponentTheme?
    private var cached: IndexBarState?

    /// 构造组件：按默认 A–Z 建好 label 栈（帧在 layoutSubviews 里竖排均分）。
    /// - Parameters:
    ///   - frame: 初始 frame。
    override public init(frame: CGRect) {
        super.init(frame: frame)
        // 无障碍：容器单元素 + 可调档（读屏上下滑逐字母，走与拖动相同的上报路径）
        isAccessibilityElement = true
        accessibilityLabel = "字母索引"
        accessibilityTraits = [.adjustable]
        rebuildLabels(count: currentItems.count)
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 每条均分高度：帧跟随 bounds 变化。
    override public func layoutSubviews() {
        super.layoutSubviews()
        let count = currentItems.count
        guard count > 0, bounds.height > 0 else { return }
        let itemHeight = bounds.height / CGFloat(count)
        for (i, label) in labels.enumerated() {
            label.frame = CGRect(x: 0, y: CGFloat(i) * itemHeight, width: bounds.width, height: itemHeight)
        }
    }

    /// 固有内容尺寸：宽固定为条宽，高不固定（Demo 用 `.frame(height:)` 给定）。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: ComponentMetrics.indexBarWidth(), height: UIView.noIntrinsicMetric)
    }

    // MARK: - BridgeView

    /// 应用最新状态：条目变化重建 label 栈，双色调与可用性差分更新。
    /// - Parameters:
    ///   - state: 最新的字母索引条状态。
    public func apply(_ state: IndexBarState) {
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if prev?.items != state.items {
            currentItems = state.items
            rebuildLabels(count: state.items.count)
            highlightedIndex = nil
            lastReported = nil
            // 读屏档位钳回新条目范围（沿用旧档位，尽量贴近用户位置）
            a11yIndex = min(a11yIndex, max(state.items.count - 1, 0))
            updateHighlight()
            invalidateIntrinsicContentSize()
        }
        // 主题化：换肤或双色调变化 → 重染全部 label（同一条重染路径）
        if themeChanged || prev?.tone != state.tone || prev?.activeTone != state.activeTone {
            updateHighlight()
        }
        if isUserInteractionEnabled != state.isEnabled {
            isUserInteractionEnabled = state.isEnabled
            alpha = state.isEnabled ? 1 : 0.4
        }
    }

    /// 拆桥：清意图回调（无手势识别器可摘）。
    public func teardown() {
        onIntent = nil
    }

    // MARK: - 触摸（touches 直接驱动）

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        handleTouch(touch)
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        handleTouch(touch)
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 松手：清除高亮（选中字母已上报过，保留最近值）
        highlightedIndex = nil
        updateHighlight()
    }

    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        highlightedIndex = nil
        updateHighlight()
    }

    // MARK: - 显示层

    /// touches 系列统一入口：y → index → 跨字母才上报 + 触感。
    private func handleTouch(_ touch: UITouch) {
        let location = touch.location(in: self)
        guard let index = IndexBarGeometry.index(forY: location.y, height: bounds.height, count: currentItems.count),
              index != highlightedIndex else { return }
        highlightedIndex = index
        updateHighlight()
        feedback.impactOccurred()
        reportItem(at: index)
    }

    /// 上报当前条目（拖动手势与读屏可调档共用）：字母没变就不上报（去重水印）。
    private func reportItem(at index: Int) {
        let item = currentItems[index]
        guard lastReported != item else { return }
        lastReported = item
        onIntent?(.changed(item))
    }

    // MARK: - 无障碍（读屏可调档）

    /// 上滑 → 下一个字母。
    override public func accessibilityIncrement() {
        adjustA11yIndex(by: 1)
    }

    /// 下滑 → 上一个字母。
    override public func accessibilityDecrement() {
        adjustA11yIndex(by: -1)
    }

    /// 读屏档位前后移一格（越界钳制），随后走与拖动相同的上报路径。
    private func adjustA11yIndex(by delta: Int) {
        guard !currentItems.isEmpty else { return }
        let next = min(max(a11yIndex + delta, 0), currentItems.count - 1)
        a11yIndex = next
        reportItem(at: a11yIndex)
    }

    /// 重建 label 栈：条目文本 + 常态样式；帧高度在 layoutSubviews 里算。
    private func rebuildLabels(count: Int) {
        for label in labels { label.removeFromSuperview() }
        labels.removeAll()

        // 主题化：常态字色走 resolvedTheme()
        let idleColor = resolvedTheme().color(for: cached?.tone ?? .neutral)
        for i in 0..<max(count, 0) {
            let label = UILabel()
            label.chain()
                .text(currentItems[i])
                .font(ComponentTypography.indexBarFont())
                .textColor(idleColor)
                .textAlignment(.center)
                .added(to: self)
            labels.append(label)
        }
    }

    /// 高亮同步：当前下标加大字号 + 激活色，其余常态。
    private func updateHighlight() {
        // 主题化：激活色 / 常态色全部走 resolvedTheme()
        let activeColor = resolvedTheme().color(for: cached?.activeTone ?? .primary)
        let idleColor = resolvedTheme().color(for: cached?.tone ?? .neutral)
        let activeFont = UIFont.systemFont(ofSize: ComponentTypography.indexBarFont().pointSize + 3, weight: .bold)
        for (i, label) in labels.enumerated() {
            let isActive = highlightedIndex == i
            label.text = currentItems[i]
            label.textColor = isActive ? activeColor : idleColor
            label.font = isActive ? activeFont : ComponentTypography.indexBarFont()
        }
    }
}