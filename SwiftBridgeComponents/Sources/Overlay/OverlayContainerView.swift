//
//  OverlayContainerView.swift
//  SwiftBridgeComponents
//
//  弹层容器视图：蒙层 dimView + 卡片位 cardView（设施：弹层容器）。
//
//  职责收敛到三件：
//    1. 按 placement 摆放卡片 —— center 居中 / bottom 顶底，尺寸由内容的 intrinsic 决定（上限裁窗）；
//    2. 进出场动画 —— dim 淡入淡出 + 卡片位移（bottom）/ 缩放（center）；
//    3. 关闭手势 —— 点蒙层、bottom 拖拽过关卡，触发后交给 onRequestDismiss（宿主决定如何关）。
//
//  不持有具体组件：三个弹层组件作为唯一子视图铺进 cardView，与容器零耦合。
//

import UIKit
import SnapKit

/// 弹层容器视图：半透明黑蒙层 + 卡片承载位。
///
/// 卡片位的布局与进出场动画都只看 OverlayPresentation，不认识具体组件；
/// 组件（Dialog / ActionSheet / BottomSheet）由宿主在 present 时作为
/// `host(_:)` 的内容铺进来。
@MainActor
public final class OverlayContainerView: UIView {

    /// 半透明黑蒙层（alpha 与动画由本视图管理）。
    public let dimView = UIView()
    /// 卡片承载位：弹层桥视图作为唯一子视图铺满；尺寸由内容 intrinsic 决定。
    public let cardView = UIView()
    /// 关闭请求（点蒙层 / 拖拽过关卡触发），由宿主接往「点击关闭」的实现。
    public var onRequestDismiss: (() -> Void)?

    private let presentation: OverlayPresentation
    private let pan = UIPanGestureRecognizer()

    /// 以展示配置创建容器。
    public init(presentation: OverlayPresentation) {
        self.presentation = presentation
        super.init(frame: .zero)
        setupSubviews()
        layoutCard()
        setupGestures()
    }

    /// `NSCoding` 初始化器不可用：容器仅支持编程式创建。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - 装配

    /// 铺垫弹层组件到卡片位（作为唯一子视图铺满，尺寸跟随其 intrinsic）。
    ///
    /// - Parameter content: 弹层桥视图（Dialog / ActionSheet / BottomSheet）。
    public func host(_ content: UIView) {
        cardView.addSubview(content)
        content.snp.makeConstraints { make in
            make.edges.equalTo(cardView)
        }
        let size = content.intrinsicContentSize
        switch presentation.placement {
        case .center:
            cardView.snp.makeConstraints { make in
                // 内容宽度/高度平权 999：窗口够大时精确取内容 intrinsic；不够时裁窗约束胜出
                make.width.equalTo(size.width).priority(999)
                make.height.equalTo(size.height).priority(999)
            }
        case .bottom:
            cardView.snp.makeConstraints { make in
                make.height.equalTo(max(size.height, 0)).priority(999)
            }
        }
    }

    // MARK: - 进出场动画

    /// 入场：从位移/缩放 + dim 淡入到终态。
    /// duration 传 0（测试）时 UIKit 即时落到终态，方便断言。
    public func animateIn() {
        let duration = presentation.animationDuration
        if presentation.placement == .bottom {
            cardView.transform = CGAffineTransform(translationX: 0, y: 32)
        } else {
            cardView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            cardView.alpha = 0
        }
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut]) {
            self.cardView.transform = .identity
            self.cardView.alpha = 1
            self.dimView.alpha = self.presentation.dimAlpha
        }
    }

    /// 出场：dim 淡出 + 卡片回位，动画结束后回调（宿主在此收容器）。
    ///
    /// - Note: 拖拽过关卡时卡片已落到底，这里再叠一层动画也只是一帧，无可见残影。
    public func animateOut(duration: TimeInterval, completion: @escaping () -> Void) {
        dimView.alpha = presentation.dimAlpha
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseIn], animations: {
            self.dimView.alpha = 0
            if self.presentation.placement == .bottom {
                self.cardView.transform = CGAffineTransform(translationX: 0, y: self.cardView.bounds.height)
            } else {
                self.cardView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                self.cardView.alpha = 0
            }
        }, completion: { _ in completion() })
    }

    // MARK: - 点蒙层 / 拖拽关闭

    /// 触发一次「点按蒙层关闭」。生产由手势驱动，测试可直接调用（@MainActor 已隔离）。
    public func fireDimTap() {
        handleDimTap()
    }

    /// 触发一次「拖拽关闭」（模拟拖过关卡）。同上，供测试直连手势逻辑。
    public func firePanSettled(_ distanceY: CGFloat, velocity: CGFloat) {
        handlePanSettled(distanceY: distanceY, velocity: velocity)
    }

    // MARK: - 私有

    private func setupSubviews() {
        dimView.backgroundColor = .black
        dimView.alpha = 0
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(dimView)

        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = presentation.placement == .bottom ? 16 : 14
        if presentation.placement == .bottom {
            cardView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
        addSubview(cardView)

        // bottom 弹层的小拖拽把手（视觉提示可拖）
        if presentation.placement == .bottom {
            let handle = UIView()
            handle.backgroundColor = UIColor.separator.withAlphaComponent(0.6)
            handle.layer.cornerRadius = 2.5
            cardView.addSubview(handle)
            handle.snp.makeConstraints { make in
                make.top.equalTo(cardView).offset(8)
                make.centerX.equalTo(cardView)
                make.width.equalTo(36)
                make.height.equalTo(5)
            }
        }
    }

    private func layoutCard() {
        cardView.snp.makeConstraints { make in
            switch presentation.placement {
            case .center:
                make.center.equalTo(self)
                make.width.lessThanOrEqualTo(self).offset(-48)
                make.height.lessThanOrEqualTo(self).offset(-80)
            case .bottom:
                make.leading.trailing.bottom.equalTo(self)
                make.height.lessThanOrEqualTo(self).offset(-60)
            }
        }
    }

    private func setupGestures() {
        if presentation.dismissOnTapDim {
            let tap = UITapGestureRecognizer(target: self, action: #selector(simulateDimTap))
            dimView.addGestureRecognizer(tap)
        }
        if presentation.placement == .bottom, presentation.dragToDismiss {
            pan.addTarget(self, action: #selector(didPan(_:)))
            cardView.addGestureRecognizer(pan)
        }
    }

    @objc private func simulateDimTap() {
        handleDimTap()
    }

    private func handleDimTap() {
        guard presentation.dismissOnTapDim else { return }
        onRequestDismiss?()
    }

    @objc private func didPan(_ gesture: UIPanGestureRecognizer) {
        let height = max(cardView.bounds.height, 1)
        switch gesture.state {
        case .changed:
            let dy = max(0, gesture.translation(in: self).y)
            cardView.transform = CGAffineTransform(translationX: 0, y: dy)
            dimView.alpha = presentation.dimAlpha * max(0, 1 - dy / (height * 0.8))
        case .ended, .cancelled:
            handlePanSettled(distanceY: gesture.translation(in: self).y,
                             velocity: gesture.velocity(in: self).y)
        default:
            break
        }
    }

    /// 松手结算：过关卡 → 卡片落底 + dim 熄灭 + 上报关闭；否则弹回原位。
    private func handlePanSettled(distanceY: CGFloat, velocity: CGFloat) {
        let height = max(cardView.bounds.height, 1)
        if distanceY > height * 0.35 || velocity > 900 {
            cardView.transform = CGAffineTransform(translationX: 0, y: max(height, distanceY))
            dimView.alpha = 0
            onRequestDismiss?()
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.cardView.transform = .identity
                self.dimView.alpha = self.presentation.dimAlpha
            })
        }
    }
}