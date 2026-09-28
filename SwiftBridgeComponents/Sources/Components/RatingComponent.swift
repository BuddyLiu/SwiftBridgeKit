//
//  RatingComponent.swift
//  SwiftBridgeComponents
//
//  评分 —— 交互组件：盘点收编 Demo01 的 RatingBridgeView，去掉了演示日志，
//  补上「星色」与「半星步进」两个可配置项。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    rating / starCount → draw（延迟到系统下一帧）
//    isEnabled          → 手势开关 + alpha
//    starTone           → 星色（.system = tintColor，保留 Demo01 原始行为）
//    allowsHalfSteps    → 手势取整步长：半星 / 整星
//  ⚠️ 星色取整的「安全网」：starTone == .system 实时读 tintColor，宿主改强调色
//     走 tintColorDidChange → setNeedsDisplay()，否则画出来的是旧色。
//     rating 在契约层 init 钳到 0...starCount（对齐 ProgressBar 的钳制约定）。
//     emit 按 lastReportedRating 去重（对齐 SearchField 的 lastReportedText），
//     同一格内连续扫过不重复上报。
//  无障碍：读屏走 accessibilityAdjustable（增减一档），放行与手势同一条上报通道。
//
//  手势只上报 Intent，不就地改自身呈现态 —— 真相由业务回写下行。
//

import UIKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 评分状态快照：星级总数、当前分、可交互性、星色与步进档。
public struct RatingState: BridgeState {
    /// 当前评分，契约层钳制到 0...starCount。
    public var rating: Double
    /// 星星总数（至少 1）。
    public var starCount: Int
    /// 是否可交互：手势开关 + alpha 表达禁用态。
    public var isEnabled: Bool
    /// 星色。`.system` = tintColor。
    public var starTone: RatingStarTone
    /// true = 半星步进（2.5）；false = 整星步进（3）。
    public var allowsHalfSteps: Bool

    /// 创建评分状态。
    /// - Parameters:
    ///   - rating: 当前评分，钳制到 0...starCount。
    ///   - starCount: 星星总数，默认 5，至少 1。
    ///   - isEnabled: 是否可交互，默认 `true`。
    ///   - starTone: 星色，默认 `.system`（随 tintColor）。
    ///   - allowsHalfSteps: 半星 / 整星步进，默认 `true`（半星）。
    public init(rating: Double,
                starCount: Int = 5,
                isEnabled: Bool = true,
                starTone: RatingStarTone = .system,
                allowsHalfSteps: Bool = true) {
        // 契约层钳制：rating 收进 0...starCount，starCount 至少 1（对齐 ProgressBar）
        self.starCount = max(starCount, 1)
        self.rating = min(max(rating, 0), Double(self.starCount))
        self.isEnabled = isEnabled
        self.starTone = starTone
        self.allowsHalfSteps = allowsHalfSteps
    }
}

/// 评分上报给业务的事件：分值变化。
public enum RatingIntent: BridgeIntent {
    /// 评分变为该值（半星或整星）；同一档内连续扫过仅上报一次。
    case changed(Double)
}

// MARK: - 评分的取整纯计算（internal，供视图用 + @testable 单测）

/// 视图不把「x 坐标 → 星级」的收边逻辑埋在手势里，统一走这里的纯函数：
/// 不收编状态、不依赖 UIKit，半星/整星步进 + 钳制的数学单测就能覆盖。
internal enum RatingGeometry {

    /// 把连续分（0...starCount）按步进取整并钳制到 [0, starCount]。
    /// - Parameter allowsHalfSteps: true 取 0.5 步进（2.5）；false 取整星（3）。
    static func snapped(raw value: Double, starCount: Int, allowsHalfSteps: Bool) -> Double {
        let base = Double(max(starCount, 1))
        let snapped: Double
        if allowsHalfSteps {
            snapped = (value * 2).rounded() / 2
        } else {
            snapped = value.rounded()
        }
        return min(base, max(0, snapped))
    }
}

// MARK: - 桥视图

@MainActor
/// 评分桥视图：点按 / 拖动 + 读屏双通道上报，`.system` 星色实时跟随 tintColor。
public final class RatingBridgeView: UIView, BridgeView {

    /// 桥状态：星级与当前分。
    public typealias State = RatingState
    /// 桥上报事件：评分变化。
    public typealias Intent = RatingIntent

    /// 事件上报通道：`.changed(分值)`，同一档去重。
    public var onIntent: ((RatingIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）。nil = 回落全局 `ComponentTheme.current`。
    /// 必须有真实存储（不能用协议默认空实现）：coordinator 下行时 `view.theme = theme`，
    /// 无存储的话写进去被丢弃，draw 里的 resolvedTheme() 永远读到 nil → override 不生效。
    public var theme: (any BridgeTheme)?

    // 呈现态缓存：只是上次快照，不是第二真相源
    private var rating: Double = 0
    private var starCount: Int = 5
    private var starTone: RatingStarTone = .system
    private var allowsHalfSteps: Bool = true
    /// 已上报过的星级，去重用（对齐 SearchField 的 lastReportedText）。
    private var lastReportedRating: Double?

    /// 创建评分桥视图：接好点按 / 拖动手势与读屏可调档。
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.chain()
            .backgroundColor(.clear)
            .contentMode(.redraw)

        // 读屏可调档：accessibilityIncrement/Decrement 走同一上报通道
        isAccessibilityElement = true
        accessibilityTraits = [.adjustable]
        accessibilityLabel = "评分"

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
    }

    @available(*, unavailable)
    /// 不支持：仅满足 NSCoding 编译要求。
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 高度 44 基线，宽度交由外部布局。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }

    // MARK: - BridgeView

    /// 应用新状态：只写真正变化的属性，随后延迟到系统下一帧重绘。
    public func apply(_ state: RatingState) {
        // ⚠️ 差异映射：只写真正变化的属性，不做无条件全量重建。
        if starCount != state.starCount { starCount = max(1, state.starCount) }
        if rating != state.rating {
            rating = state.rating
            // 业务回写新值后重置去重基线：下次手势刻在同一档也属于「可上报的新意图」
            lastReportedRating = nil
        }
        if starTone != state.starTone { starTone = state.starTone }
        if allowsHalfSteps != state.allowsHalfSteps { allowsHalfSteps = state.allowsHalfSteps }
        if isUserInteractionEnabled != state.isEnabled {
            isUserInteractionEnabled = state.isEnabled
        }
        alpha = state.isEnabled ? 1 : 0.4
        setNeedsDisplay()
    }

    /// 拆桥：清事件通道，保持幂等（dismantle 与 deinit 两条路径都可能触发）。
    public func teardown() {
        // 必须幂等：dismantle 与 deinit 两条路径都可能触发
        onIntent = nil
    }

    // MARK: - 手势 → 意图

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        emit(at: gesture.location(in: self).x)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            emit(at: gesture.location(in: self).x)
        default:
            break
        }
    }

    private func emit(at x: CGFloat) {
        guard bounds.width > 0 else { return }

        let raw = Double(x / bounds.width) * Double(max(starCount, 1))
        let clamped = RatingGeometry.snapped(raw: raw,
                                             starCount: starCount,
                                             allowsHalfSteps: allowsHalfSteps)

        // 上报去重：同一档内连续扫过只报一次（对齐 SearchField 的 lastReportedText）。
        // 这是「意图级」去重不是呈现态改动 —— 真相仍由业务回写。
        guard clamped != lastReportedRating else { return }
        lastReportedRating = clamped

        // ⚠️ 关键：只上报意图，**不在这里改自己的呈现态**。
        //    真相由业务回写，桥不持有第二份数据源。
        onIntent?(.changed(clamped))
    }

    // MARK: - 无障碍（读屏可调档）

    /// 屏幕朗读用；tone 变化不在此重绘（不归 draw 管）。
    /// 读屏值带星数分母：半星 `3.0/5`，整星 `3/5`。
    override public var accessibilityValue: String? {
        get {
            let denominator = Double(max(starCount, 1))
            if allowsHalfSteps {
                return String(format: "%.1f/%.0f", rating, denominator)
            }
            return String(format: "%.0f/%.0f", rating, denominator)
        }
        set {}
    }

    /// 上滑 / 右上扫 → +1 档。
    override public func accessibilityIncrement() {
        adjustBy(1)
    }

    /// 下滑 / 左上扫 → -1 档。
    override public func accessibilityDecrement() {
        adjustBy(-1)
    }

    private func adjustBy(_ delta: Double) {
        let next = RatingGeometry.snapped(raw: rating + delta,
                                          starCount: starCount,
                                          allowsHalfSteps: allowsHalfSteps)
        guard next != rating else { return }
        lastReportedRating = next
        onIntent?(.changed(next))
    }

    // MARK: - 绘制

    /// tintColor 变化时触发重绘：`.system` 星色实时读新色，避免画出旧色。
    override public func tintColorDidChange() {
        super.tintColorDidChange()
        // starTone == .system 实时读 tintColor：宿主改强调色必须重绘，否则显示旧色
        setNeedsDisplay()
    }

    /// 按星级与当前分差值画星：>=1 整星、>=0.5 半透明星、否则空星。
    override public func draw(_ rect: CGRect) {
        guard starCount > 0, rect.width > 0 else { return }

        let side = min(rect.height, rect.width / CGFloat(starCount))
        let font = UIFont.systemFont(ofSize: side * 0.78)
        // 主题化：星色走每桥覆盖（resolvedTheme = 桥自带 theme ?? 全局 current）。
        // Rating 的 apply 无条件 setNeedsDisplay()，换肤时 coordinator 重放 apply → 重绘自动跟上。
        let filledColor = resolvedTheme().starColor(for: starTone)
        let emptyColor = UIColor.tertiaryLabel

        for index in 0..<starCount {
            let delta = rating - Double(index)

            let symbol: String
            let color: UIColor
            if delta >= 1 {
                symbol = "★"; color = filledColor
            } else if delta >= 0.5 {
                symbol = "★"; color = filledColor.withAlphaComponent(0.5)
            } else {
                symbol = "☆"; color = emptyColor
            }

            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let text = symbol as NSString
            let textSize = text.size(withAttributes: attributes)
            let origin = CGPoint(
                x: CGFloat(index) * side + (side - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2
            )
            text.draw(at: origin, withAttributes: attributes)
        }
    }
}