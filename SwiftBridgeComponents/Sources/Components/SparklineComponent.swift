//
//  SparklineComponent.swift
//  SwiftBridgeComponents
//
//  迷你趋势图 —— 展示组件：一维数值序列折线（可选浅色填充带），tone 换色。
//
//  设计对齐 Rating 的绘制纪律：
//    · 全部内容在 draw(_:) 里画（折线 + 填充带），无子视图装配成本；
//    · 数值纵坐标按 min/max 归一化到画布，序列长短自适应；
//    · apply 只在真正变化时 setNeedsDisplay()，换肤走 themeChanged 强制重绘；
//    · 纯展示不交互，Intent 走 NoIntent（对齐 ProgressBar）。
//  契约层不钳值：空序列合法（画空画布、读屏报「暂无数据」），[0, ∞) 任意值。
//
//  无障碍：容器单元素（label=迷你趋势图，value=「N 个数据点 · 最低 X · 最高 Y」），
//  值为只读文本（对齐 IndexBar 之外的空读，不做 adjustable）。
//  主题：tone 决定折线与填充带颜色（resolvedTheme = 每桥 override ?? 全局 current）。
//

import UIKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 迷你趋势图状态：数值序列 + 配色 + 是否画填充带（只读）。
public struct SparklineState: BridgeState {
    /// 数值序列（展示顺序即横坐标顺序）；空/单点等边界情况由视图兜底。
    public var points: [Double]
    /// 配色主题：折线与填充带颜色。
    public var tone: ComponentTone
    /// 是否画折线下方浅色填充带（软色底）。
    public var showsFill: Bool

    /// 构造迷你趋势图状态。
    /// - Parameters:
    ///   - points: 数值序列。
    ///   - tone: 配色主题；默认 .primary。
    ///   - showsFill: 是否画填充带；默认 true。
    public init(points: [Double],
                tone: ComponentTone = .primary,
                showsFill: Bool = true) {
        self.points = points
        self.tone = tone
        self.showsFill = showsFill
    }
}

// MARK: - 桥视图

/// 迷你趋势图桥视图：绘制型展示组件，折线 + 可选填充带。
@MainActor
public final class SparklineBridgeView: UIView, BridgeView {

    /// 桥状态类型：数值序列 / 配色 / 填充带开关。
    public typealias State = SparklineState
    /// 桥事件类型固定为 `NoIntent`：展示型组件不上报事件。
    public typealias Intent = NoIntent

    /// 事件上报通道：展示型组件无事件，保留以适配 BridgeView 协议。
    public var onIntent: ((NoIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）；`resolvedTheme()` = 本属性 ?? 全局 current。
    public var theme: (any BridgeTheme)?
    private var cached: SparklineState?
    /// 上次生效主题缓存：主题变化强制重绘（themeChanged）。
    private var cachedTheme: ComponentTheme?

    /// 构造组件：透明底、随布局重绘（对齐 Rating 的绘制型内容 Mode）。
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.chain()
            .backgroundColor(.clear)
            .contentMode(.redraw)
            .isAccessibilityElement(true)
            .accessibilityLabel("迷你趋势图")
            .accessibilityTraits([.updatesFrequently])
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：高度恒定 56（对齐步骤条的阅读空间），宽度交由外部布局。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: ComponentMetrics.sparklineHeight())
    }

    // MARK: - BridgeView

    /// 应用最新状态：序列 / 配色 / 填充开关任一变化 → 更新读屏值并延迟到下一帧重绘。
    /// - Parameters:
    ///   - state: 最新的迷你趋势图状态。
    public func apply(_ state: SparklineState) {
        // 主题解析：每桥覆盖优先，否则回落全局 current；themeChanged 时强制重绘
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if themeChanged || prev?.points != state.points
            || prev?.tone != state.tone || prev?.showsFill != state.showsFill {
            updateAccessibilityValue()
            setNeedsDisplay()
        }
    }

    /// 拆桥：清事件通道（幂等，dismantle 与 deinit 两条路径都可能触发）。
    public func teardown() {
        onIntent = nil
    }

    // MARK: - 无障碍

    /// 读屏值：数据点密度 + 最低/最高（取整）；空序列报「暂无数据」。
    private func updateAccessibilityValue() {
        guard let state = cached, !state.points.isEmpty else {
            accessibilityValue = "暂无数据"
            return
        }
        let lo = state.points.min().map { Int($0.rounded()) } ?? 0
        let hi = state.points.max().map { Int($0.rounded()) } ?? 0
        accessibilityValue = "\(state.points.count) 个数据点 · 最低 \(lo) · 最高 \(hi)"
    }

    // MARK: - 绘制

    /// 归一化绘制：单点画小圆点；多点画折线（可选浅色填充带）。
    override public func draw(_ rect: CGRect) {
        guard let state = cached, !state.points.isEmpty else { return }
        let theme = resolvedTheme()

        let n = state.points.count
        let lineColor = theme.color(for: state.tone)
        let fillColor = theme.softBackground(for: state.tone)

        // 纵坐标按 min/max 归一化；横坐标均匀铺满（序列首尾贴边）
        let lo = state.points.min() ?? 0
        let hi = state.points.max() ?? 0
        let spread = hi - lo

        func x(_ i: Int) -> CGFloat {
            rect.minX + rect.width * (CGFloat(i) / CGFloat(max(n - 1, 1)))
        }
        func y(_ value: Double) -> CGFloat {
            if spread == 0 { return rect.midY }           // 全等值 → 水平中线
            return rect.maxY - rect.height * CGFloat((value - lo) / spread)
        }

        if n == 1 {
            let point = CGPoint(x: rect.midX, y: y(state.points[0]))
            let dot = UIBezierPath(ovalIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
            lineColor.setFill()
            dot.fill()
            return
        }

        let line = UIBezierPath()
        line.move(to: CGPoint(x: x(0), y: y(state.points[0])))
        for i in 1..<n {
            line.addLine(to: CGPoint(x: x(i), y: y(state.points[i])))
        }
        line.lineWidth = 2
        line.lineJoinStyle = .round
        line.lineCapStyle = .round

        // 填充带：折线闭合回底部（同一路径描两次填）
        if state.showsFill {
            let fill = line.copy() as! UIBezierPath
            fill.addLine(to: CGPoint(x: x(n - 1), y: rect.maxY))
            fill.addLine(to: CGPoint(x: x(0), y: rect.maxY))
            fill.close()
            fillColor.setFill()
            fill.fill()
        }

        lineColor.setStroke()
        line.stroke()
    }
}