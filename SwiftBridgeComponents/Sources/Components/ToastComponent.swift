//
//  ToastComponent.swift
//  SwiftBridgeComponents
//
//  浮动消息 —— 浮层组件：底部浮出卡片 + 图标/文案/tone，可选自动消失 + 点按。
//
//  教学点延续 Notice/Carousel：自动消失 = 长寿命异步对象（私有 owner 型弱代理
//  Timer），teardown 必须先 invalidate + 置 nil；且显隐由业务控制（保持唯一真相），
//  组件只管「展示 + 上报 .tapped / .autoDismissed」。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    message / icon → 文案 / 图标显隐
//    tone            → 卡片浅底 + 文案/图标色
//    isPresented     → 进出场动画 + 停启计时器
//    autoDismissAfter → 展示中改档 / 取消；到点上报 .autoDismissed
//    dismissOnTap     → 卡片挂/摘点按手势
//    bottomOffset     → 距容器底内缩
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// Toast 组件的 State：文案/图标/tone 与显隐、自动消失、点按等展示控制项。
///
/// 显隐由业务控制（`isPresented` 是唯一真相），组件只负责展示与上报意图。
public struct ToastState: BridgeState {
    /// 提示文案。
    public var message: String
    /// SF Symbol 名；nil = 不显示图标。
    public var icon: String?
    /// 色调基调：决定卡片浅底与文案/图标主色。
    public var tone: ComponentTone
    /// 业务控制显隐：true 浮出，false 收起（组件不自行移除）。
    public var isPresented: Bool
    /// 到点自动上报 .autoDismissed（秒）；nil = 不自动消失。
    public var autoDismissAfter: Double?
    /// 点按卡片是否上报 .tapped。
    public var dismissOnTap: Bool
    /// 卡片距容器底部的距离（pt）。
    public var bottomOffset: CGFloat

    /// 构造 Toast 状态。
    ///
    /// - Parameters:
    ///   - message: 提示文案。
    ///   - icon: SF Symbol 名；nil = 不显示图标（默认 `nil`）。
    ///   - tone: 色调基调（默认 `.primary`）。
    ///   - isPresented: 业务控制的显隐位（默认 `false`）。
    ///   - autoDismissAfter: 自动消失秒数；nil = 不自动消失（默认 `nil`）。
    ///   - dismissOnTap: 点按卡片是否上报 `.tapped`（默认 `true`）。
    ///   - bottomOffset: 卡片距容器底部距离（pt，默认 `24`）。
    public init(message: String,
                icon: String? = nil,
                tone: ComponentTone = .primary,
                isPresented: Bool = false,
                autoDismissAfter: Double? = nil,
                dismissOnTap: Bool = true,
                bottomOffset: CGFloat = 24) {
        self.message = message
        self.icon = icon
        self.tone = tone
        self.isPresented = isPresented
        self.autoDismissAfter = autoDismissAfter
        self.dismissOnTap = dismissOnTap
        self.bottomOffset = bottomOffset
    }
}

/// Toast 交互意图：点按卡片与自动消失到点。
public enum ToastIntent: BridgeIntent {
    /// 点按卡片（dismissOnTap 时触发；显隐仍由业务决定）。
    case tapped
    /// 自动消失计时到点。
    case autoDismissed
}

// MARK: - 桥视图

/// Toast 桥视图：底部浮出卡片 + 图标/文案，进出场动画与自动消失计时在此管理。
///
/// 显隐切换由 `apply(_:)` 的 `isPresented` 差异驱动；动画与计时到点只上报意图，
/// 不自行改变状态（保持业务为唯一真相）。
@MainActor
public final class ToastBridgeView: UIView, BridgeView {

    /// 关联的契约状态类型。
    public typealias State = ToastState
    /// 关联的契约意图类型。
    public typealias Intent = ToastIntent

    /// 意图回调：`tapped` / `autoDismissed` 在此上报给宿主。
    public var onIntent: ((ToastIntent) -> Void)?

    private let card = UIView()
    private let stack = UIStackView()
    private let iconView = UIImageView()
    private let label = UILabel()
    private let tap = UITapGestureRecognizer()
    private var timer: Timer?
    private var bottomConstraint: Constraint?
    private var cached: ToastState?

    /// 以 frame 创建桥视图，并完成卡片、内容栈、约束与点按手势的构建。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        // 卡片：tone 浅底 + 圆角，内容由 stack 内边距撑起
        card.chain()
            .clipsToBounds(true)
            .cornerRadius(ComponentMetrics.toastCornerRadius())
            .alpha(0)
            .transform(CGAffineTransform(translationX: 0, y: 12))
            .added(to: self)

        iconView.chain()
            .contentMode(.scaleAspectFit)
            .isHidden(true)
            .autolayout()
            .build()

        label.chain()
            .font(ComponentTypography.toastFont())
            .numberOfLines(0)
            .autolayout()
            .build()

        // 水平栈：图标 + 文案，内容内边距撑起卡片高度
        stack.chain()
            .axis(.horizontal)
            .alignment(.center)
            .spacing(8)
            .isLayoutMarginsRelativeArrangement(true)
            .directionalLayoutMargins(NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            .arrangedSubviews([iconView, label])
            .added(to: card)

        iconView.snp.makeConstraints { make in
            make.size.equalTo(ComponentMetrics.toastIconSize())
        }

        card.snp.makeConstraints { make in
            // 卡片水平居中，两边留 24 内缩；竖直锚到容器底 - bottomOffset
            make.centerX.equalTo(self)
            make.leading.greaterThanOrEqualTo(self).offset(24)
            make.trailing.lessThanOrEqualTo(self).offset(-24)
            make.height.greaterThanOrEqualTo(ComponentMetrics.toastCardHeight())

            // bottomOffset 单独存引用，apply 里可改
            bottomConstraint = make.bottom.equalTo(self).offset(-ComponentMetrics.toastBottomOffset()).constraint
        }

        stack.snp.makeConstraints { make in
            make.edges.equalTo(card)
        }

        // 默认挂点按手势（dismissOnTap 默认 true）；暂不加入视图，由 apply 控制
        tap.addTarget(self, action: #selector(handleTap))
    }

    /// `NSCoding` 初始化器不可用：组件仅支持编程式创建（`init(frame:)`）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固定内容尺寸：宽度自适应，高度取 140 占位（卡片实际高度由内容与约束撑起）。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 140)
    }

    // MARK: - BridgeView

    /// 按状态差异更新展示：文案/图标/tone 等仅在差异时刷新，显隐切换驱动进出场动画。
    ///
    /// 已展示时改档或取消自动消失会直接重置计时器（映射见文件头「差异映射字段清单」）。
    public func apply(_ state: ToastState) {
        let prev = cached
        cached = state

        if prev?.message != state.message {
            label.text = state.message
        }
        if prev?.icon != state.icon {
            if let icon = state.icon {
                iconView.image = UIImage(systemName: icon)
                iconView.isHidden = false
            } else {
                iconView.image = nil
                iconView.isHidden = true
            }
        }
        if prev?.tone != state.tone {
            applyTone(state.tone)
        }
        if prev?.dismissOnTap != state.dismissOnTap {
            updateTap(to: state.dismissOnTap)
        }
        if prev?.bottomOffset != state.bottomOffset {
            bottomConstraint?.update(offset: -state.bottomOffset)
        }
        if prev?.isPresented != state.isPresented {
            setPresented(state.isPresented)
        }
        // 已展示中改档 / 取消自动消失（重展示走 setPresented 里的停启逻辑）
        if prev?.autoDismissAfter != state.autoDismissAfter, cached?.isPresented == true {
            updateTimer(state.autoDismissAfter)
        }
    }

    /// 拆除桥视图：先 invalidate 并置空计时器（收口长寿命异步对象），再摘手势、断开回调。
    public func teardown() {
        // 长寿命异步对象先收口，再摘手势、断上报通道
        timer?.invalidate()
        timer = nil
        card.removeGestureRecognizer(tap)
        onIntent = nil
    }

    // MARK: - 差异映射

    private func applyTone(_ tone: ComponentTone) {
        let color = ComponentPalette.color(for: tone)
        card.backgroundColor = ComponentPalette.softBackground(for: tone)
        label.textColor = color
        iconView.tintColor = color
    }

    private func setPresented(_ presented: Bool) {
        if presented {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
                self.card.alpha = 1
                self.card.transform = .identity
            }
            if let interval = cached?.autoDismissAfter, interval > 0 {
                updateTimer(interval)
            }
        } else {
            // 收起必须停计时器，否则到点还上报
            updateTimer(nil)
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn]) {
                self.card.alpha = 0
                self.card.transform = CGAffineTransform(translationX: 0, y: 12)
            }
        }
    }

    // MARK: - 自动消失（长寿命异步对象）

    private func updateTimer(_ interval: Double?) {
        timer?.invalidate()
        timer = nil
        guard let interval, interval > 0, cached?.isPresented == true else { return }

        let timer = Timer(timeInterval: interval,
                          target: WeakTimerProxy(self),
                          selector: #selector(WeakTimerProxy.fire),
                          userInfo: nil,
                          repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    fileprivate func autoDismissed() {
        timer?.invalidate()
        timer = nil
        onIntent?(.autoDismissed)
    }

    private func updateTap(to enabled: Bool) {
        if enabled {
            if tap.view == nil { card.addGestureRecognizer(tap) }
        } else {
            card.removeGestureRecognizer(tap)
        }
    }

    @objc private func handleTap() {
        guard cached?.dismissOnTap == true else { return }
        onIntent?(.tapped)
    }
}

// MARK: - Timer 的弱代理

/// Timer 强持有 target：用 NSObject 代理只持 weak owner，避免 ToastBridgeView ↔ Timer
/// 相互保活。回调经 assumeIsolated 落回主演员（与 Carousel/Notice 同款写法）。
/// 拆桥路径：teardown 里先 timer.invalidate() + 置 nil，否则到点空转上报。
private final class WeakTimerProxy: NSObject {
    private weak var owner: ToastBridgeView?

    init(_ owner: ToastBridgeView) {
        self.owner = owner
    }

    @objc func fire() {
        guard let owner else { return }
        MainActor.assumeIsolated {
            owner.autoDismissed()
        }
    }
}