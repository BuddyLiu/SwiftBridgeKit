//
//  StepIndicatorComponent.swift
//  SwiftBridgeComponents
//
//  步骤指示器 —— 展示组件：圆形步骤条（勾 ✓ / 当前步 / 未来步 + 标题 + 完成段连线）。
//
//  设计对齐 Rating 的绘制纪律：
//    · 全部内容在 draw(_:) 里画（圆 + 序号/勾 + 标题 + 连线），无子视图装配成本；
//    · apply 只在真正变化时 setNeedsDisplay()，换肤走 themeChanged 强制重绘；
//    · 纯展示不交互，Intent 走 NoIntent（对齐 ProgressBar）。
//  契约层已钳制 currentIndex（0...steps.count-1），视图侧不再防越界。
//
//  无障碍：容器单元素（label=步骤进度，value=「第 X / N 步 · 步骤名」），
//  值为只读文本（对齐 ProgressBar 只读百分比，不做 adjustable）。
//  主题：tone 决定已完成段与当前步描边颜色（resolvedTheme = 每桥 override ?? 全局 current）。
//

import UIKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 步骤指示器状态：步骤标题集合 + 当前进度 + 配色（只读）。
public struct StepIndicatorState: BridgeState {
    /// 步骤标题（顺序即展示顺序）；至少期望给 2 个以上。
    public var steps: [String]
    /// 当前步下标（0 起）。init 钳到 0...steps.count-1；empty 时钳为 0。
    public var currentIndex: Int
    /// 配色主题：已完成段与当前步描边色。
    public var tone: ComponentTone

    /// 构造步骤指示器状态。
    /// - Parameters:
    ///   - steps: 步骤标题集合。
    ///   - currentIndex: 当前步下标，默认 0；init 里钳到 0...steps.count-1。
    ///   - tone: 配色主题；默认 .primary。
    public init(steps: [String],
                currentIndex: Int = 0,
                tone: ComponentTone = .primary) {
        self.steps = steps
        // 契约层钳制：空步骤集时视为 0；否则收进 0...count-1
        self.currentIndex = steps.isEmpty ? 0 : min(max(currentIndex, 0), steps.count - 1)
        self.tone = tone
    }
}

// MARK: - 连线端点几何（internal，供 draw 用 + @testable 单测）

/// 步骤连线的纯计算，不收编状态、不依赖 UIKit：
/// 完成段连线端点必须停在「当前步节点圆周」上、不直穿圆心 ——
/// 否则线段会透过半透明浅底圈透出来，看起来与序号重叠（Demo11 实测复现）。
internal enum StepIndicatorGeometry {

    /// 完成段连线右端点 x：当前步节点「左圆周」（圆心 - 半径）。
    /// 当前步恰是末个时，该值自然落到末节点左圆周，与基线灰线端点一致。
    /// - Parameters:
    ///   - step: 当前步下标（已钳制到 0...count-1，≥ 1 才有完成段）。
    ///   - nodeW: 每节点槽宽。
    ///   - inset: 圆半径（连线要退让的圆周距离）。
    ///   - marginX: 左右边距。
    static func segmentEndX(step: Int, nodeW: CGFloat, inset: CGFloat, marginX: CGFloat) -> CGFloat {
        let centerX = marginX + nodeW * (CGFloat(step) + 0.5)
        return centerX - inset
    }
}

// MARK: - 桥视图

/// 步骤指示器桥视图：绘制型展示组件，步骤进度只读呈现。
@MainActor
public final class StepIndicatorBridgeView: UIView, BridgeView {

    /// 桥状态类型：步骤集合 / 当前步 / 配色。
    public typealias State = StepIndicatorState
    /// 桥事件类型固定为 `NoIntent`：展示型组件不上报事件。
    public typealias Intent = NoIntent

    /// 事件上报通道：展示型组件无事件，保留以适配 BridgeView 协议。
    public var onIntent: ((NoIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）；`resolvedTheme()` = 本属性 ?? 全局 current。
    public var theme: (any BridgeTheme)?
    private var cached: StepIndicatorState?
    /// 上次生效主题缓存：主题变化强制重绘（themeChanged）。
    private var cachedTheme: ComponentTheme?

    /// 构造组件：透明底、随布局重绘（对齐 Rating 的绘制型内容 Mode）。
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.chain()
            .backgroundColor(.clear)
            .contentMode(.redraw)
            .isAccessibilityElement(true)
            .accessibilityLabel("步骤进度")
            .accessibilityTraits([.updatesFrequently])
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：高度容纳圆 + 标题两段（56），宽度交由外部布局。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: ComponentMetrics.stepIndicatorHeight())
    }

    // MARK: - BridgeView

    /// 应用最新状态：内容任何一项变化 → 更新读屏值并延迟到下一帧重绘。
    /// - Parameters:
    ///   - state: 最新的步骤指示器状态。
    public func apply(_ state: StepIndicatorState) {
        // 主题解析：每桥覆盖优先，否则回落全局 current；themeChanged 时强制重绘
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if themeChanged || prev?.steps != state.steps
            || prev?.currentIndex != state.currentIndex || prev?.tone != state.tone {
            updateAccessibilityValue()
            setNeedsDisplay()
        }
    }

    /// 拆桥：清事件通道（幂等，dismantle 与 deinit 两条路径都可能触发）。
    public func teardown() {
        onIntent = nil
    }

    // MARK: - 无障碍

    /// 读屏值：当前步的「第 X / N 步 · 步骤名」；空步骤集给「暂无步骤」。
    private func updateAccessibilityValue() {
        guard let state = cached, !state.steps.isEmpty else {
            accessibilityValue = "暂无步骤"
            return
        }
        let step = min(max(state.currentIndex, 0), state.steps.count - 1)
        accessibilityValue = "第 \(step + 1) / \(state.steps.count) 步 · \(state.steps[step])"
    }

    // MARK: - 绘制

    /// 按步骤排布绘制：完成段连线 + 各节点圆（勾/当前/未来）+ 标题。
    override public func draw(_ rect: CGRect) {
        guard let state = cached, !state.steps.isEmpty else { return }
        let theme = resolvedTheme()

        let count = state.steps.count
        let step = min(max(state.currentIndex, 0), count - 1)

        // 几何常量：圆 20 + 间隙 8 + 标题行 14；左右留 12 边距
        let circleD: CGFloat = 20
        let gap: CGFloat = 8
        let titleH: CGFloat = 14
        let marginX: CGFloat = 12

        let top = (rect.height - (circleD + gap + titleH)) / 2
        let centerY = top + circleD / 2
        let nodeW = (rect.width - marginX * 2) / CGFloat(count)

        func centerX(_ i: Int) -> CGFloat {
            marginX + nodeW * (CGFloat(i) + 0.5)
        }

        let tint = theme.color(for: state.tone)
        let soft = theme.softBackground(for: state.tone)

        // 1) 连接线（画在圆后面）：基线全宽灰线，已完成段用主题色覆盖到当前步
        if count > 1 {
            let inset = circleD / 2
            let firstX = centerX(0)
            let lastX = centerX(count - 1)

            let base = UIBezierPath()
            base.move(to: CGPoint(x: firstX + inset, y: centerY))
            base.addLine(to: CGPoint(x: lastX - inset, y: centerY))
            base.lineWidth = 1.5
            base.lineCapStyle = .round
            UIColor.separator.setStroke()
            base.stroke()

            if step > 0 {
                let done = UIBezierPath()
                done.move(to: CGPoint(x: firstX + inset, y: centerY))
                // ⚠️ 完成段止于「当前步节点左圆周」而非圆心：
                //    直接 centerX(step) 会让线段穿过半透明浅底圈露出、与序号重叠。
                //    min 兜底：step 为末个时退让到末节点左圆周（与灰线一致）。
                let endX = StepIndicatorGeometry.segmentEndX(step: step, nodeW: nodeW,
                                                             inset: inset, marginX: marginX)
                done.addLine(to: CGPoint(x: min(endX, lastX - inset), y: centerY))
                done.lineWidth = 1.5
                done.lineCapStyle = .round
                tint.setStroke()
                done.stroke()
            }
        }

        // 2) 逐节点：圆 + 勾/序号 + 标题
        for i in 0..<count {
            let cx = centerX(i)
            let circleRect = CGRect(x: cx - circleD / 2, y: centerY - circleD / 2,
                                    width: circleD, height: circleD)

            if i < step {
                // 已完成：主题色实心 + 白勾
                let path = UIBezierPath(ovalIn: circleRect)
                tint.setFill()
                path.fill()
                drawCentered("✓", in: circleRect,
                             font: UIFont.systemFont(ofSize: 12, weight: .bold), color: .white)
            } else if i == step {
                // 当前步：浅底 + 主题色描边 + 序号
                let path = UIBezierPath(ovalIn: circleRect)
                soft.setFill()
                path.fill()
                tint.setStroke()
                path.lineWidth = 2
                path.stroke()
                drawCentered("\(i + 1)", in: circleRect,
                             font: UIFont.systemFont(ofSize: 11, weight: .semibold), color: tint)
            } else {
                // 未来步：灰底 + 分隔线描边 + 序号
                let path = UIBezierPath(ovalIn: circleRect)
                UIColor.systemGray6.setFill()
                path.fill()
                UIColor.separator.setStroke()
                path.lineWidth = 1
                path.stroke()
                drawCentered("\(i + 1)", in: circleRect,
                             font: UIFont.systemFont(ofSize: 11, weight: .regular), color: .secondaryLabel)
            }

            // 标题（步骤名）：当前步加粗 + 已到步骤用主色，未来步用次色
            let title = state.steps[i] as NSString
            let titleFont = UIFont.systemFont(ofSize: 11, weight: i == step ? .semibold : .regular)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: i <= step ? UIColor.label : UIColor.secondaryLabel,
            ]
            let size = title.size(withAttributes: attrs)
            let tRect = CGRect(x: cx - nodeW / 2,
                               y: top + circleD + gap + (titleH - size.height) / 2,
                               width: nodeW, height: size.height)
            title.draw(with: tRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                       attributes: attrs, context: nil)
        }
    }

    /// 在给定矩形内居中绘制单行文本（供圆内勾/序号用）。
    private func drawCentered(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let string = text as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = string.size(withAttributes: attrs)
        string.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                    withAttributes: attrs)
    }
}