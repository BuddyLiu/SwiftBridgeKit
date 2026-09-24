//
//  NoticeComponent.swift
//  SwiftBridgeComponents
//
//  通知横幅 —— 展示为主：图标 + 标题（+ 副文案）+ 可选关闭按钮。
//  适合表单校验提示、状态反馈等「一条横幅」场景。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    title/message → 文案 + invalidateIntrinsic（高度自适应）
//    tone           → 图标 / 标题色 + 浅底
//    icon           → SF Symbol 名（nil = 按 tone 给默认图标）
//    showsClose     → 关闭按钮显隐
//    autoDismissAfter → 一次性 Timer 自动消失（本包第二个长寿命异步对象，走共享弱代理；
//                        teardown 必须先 invalidate + 置 nil）
//  点关闭只上报 .close、到点只上报 .autoDismissed，是否移除横幅由业务决定（保持「唯一真相」）。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 通知横幅的状态快照：文案、色调、图标、关闭按钮显隐与自动消失时长。
public struct NoticeState: BridgeState {
    /// 主标题文案（必填）。
    public var title: String
    /// 副文案；nil = 只显示标题。
    public var message: String?
    /// 语义色调：图标与标题取主色、背景取浅底。
    public var tone: ComponentTone
    /// SF Symbol 名；nil 时按 tone 取默认图标。
    public var icon: String?
    /// 是否显示右上角关闭按钮。
    public var showsClose: Bool
    /// 到点自动上报 .autoDismissed（秒）；nil = 不自动消失。业务收到后决定是否移除横幅。
    public var autoDismissAfter: Double?

    /// 创建通知横幅状态。
    /// - Parameters:
    ///   - title: 主标题文案。
    ///   - message: 副文案，默认 nil（不显示）。
    ///   - tone: 语义色调，默认 `.primary`。
    ///   - icon: 自定义 SF Symbol 名，默认 nil（按 tone 取默认图标）。
    ///   - showsClose: 是否显示关闭按钮，默认 `false`。
    ///   - autoDismissAfter: 自动消失秒数，默认 nil（不自动消失）。
    public init(title: String,
                message: String? = nil,
                tone: ComponentTone = .primary,
                icon: String? = nil,
                showsClose: Bool = false,
                autoDismissAfter: Double? = nil) {
        self.title = title
        self.message = message
        self.tone = tone
        self.icon = icon
        self.showsClose = showsClose
        self.autoDismissAfter = autoDismissAfter
    }
}

/// 通知横幅上报给业务的事件：用户关闭 / 自动消失。
public enum NoticeIntent: BridgeIntent {
    /// 用户点击了关闭按钮。
    case close
    /// 自动消失计时到点。
    case autoDismissed
}

// MARK: - 桥视图

@MainActor
/// 通知横幅桥视图：展示型组件，逐字段差分，自动消失走共享弱代理 Timer。
public final class NoticeBridgeView: UIView, BridgeView {

    /// 桥状态：横幅内容与形态。
    public typealias State = NoticeState
    /// 桥上报事件：关闭与自动消失。
    public typealias Intent = NoticeIntent

    /// 事件上报通道：`.close` 与 `.autoDismissed`。
    public var onIntent: ((NoticeIntent) -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private var timer: Timer?
    private var cached: NoticeState?

    /// 创建横幅桥视图：搭好图标 / 标题 / 副文案 / 关闭按钮布局。
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.chain().clipsToBounds(true).cornerRadius(10)

        iconView.chain()
            .contentMode(.scaleAspectFit)
            .added(to: self)

        titleLabel.chain()
            .font(ComponentTypography.noticeTitleFont())
            .added(to: self)

        messageLabel.chain()
            .font(ComponentTypography.noticeBodyFont())
            .textColor(.secondaryLabel)
            .added(to: self)

        closeButton.chain()
            .symbol("xmark.circle.fill", for: .normal)
            .tintColor(.secondaryLabel)
            .target(self, action: #selector(handleClose), for: .touchUpInside)
            .added(to: self)

        let pad: CGFloat = 12
        iconView.snp.makeConstraints { make in
            make.leading.equalTo(self).offset(pad)
            make.centerY.equalTo(self)
            make.size.equalTo(20)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(self).offset(pad - 4)
            make.leading.equalTo(iconView.snp.trailing).offset(10)
            make.trailing.lessThanOrEqualTo(closeButton.snp.leading).offset(-8)
        }

        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.leading.equalTo(titleLabel.snp.leading)
            make.trailing.lessThanOrEqualTo(closeButton.snp.leading).offset(-8)
        }

        closeButton.snp.makeConstraints { make in
            make.trailing.equalTo(self).offset(-pad)
            make.centerY.equalTo(self)
            make.size.equalTo(24)
        }
    }

    @available(*, unavailable)
    /// 不支持：仅满足 NSCoding 编译要求。
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 高度按标题与副文案自适应（内容变化后 invalidateIntrinsic 重算），宽度交给行宽。
    override public var intrinsicContentSize: CGSize {
        // 高度：标题行 20 + 副文案 18 + 上下 padding；宽度交给行宽
        let height = ComponentMetrics.noticeHeight(showsMessage: cached?.message != nil)
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    // MARK: - BridgeView

    /// 应用新状态：逐字段差分，文案变化时 invalidate 高度布局。
    public func apply(_ state: NoticeState) {
        let prev = cached
        cached = state

        if prev?.title != state.title {
            titleLabel.text = state.title
        }
        if prev?.message != state.message {
            messageLabel.text = state.message
            messageLabel.isHidden = state.message == nil
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
        if prev?.tone != state.tone {
            let color = ComponentPalette.color(for: state.tone)
            backgroundColor = ComponentPalette.softBackground(for: state.tone)
            titleLabel.textColor = color
            iconView.tintColor = color
        }
        if prev?.icon != state.icon {
            let name = state.icon ?? Self.defaultIcon(for: state.tone)
            iconView.image = UIImage(systemName: name)
        }
        if prev?.showsClose != state.showsClose {
            closeButton.isHidden = !state.showsClose
        }
        if prev?.autoDismissAfter != state.autoDismissAfter {
            updateTimer(state.autoDismissAfter)
        }
    }

    /// 拆桥：先停自动消失 Timer 并断关闭按钮，再清事件通道，防止拆桥后长寿命对象空转回调。
    public func teardown() {
        // 先停长寿命异步对象，再断事件通道
        timer?.invalidate()
        timer = nil
        closeButton.removeTarget(self, action: nil, for: .allEvents)
        onIntent = nil
    }

    // MARK: - 自动消失（长寿命异步对象）

    private func updateTimer(_ interval: Double?) {
        timer?.invalidate()
        timer = nil
        guard let interval, interval > 0 else { return }

        // 复用私有弱代理 WeakTimerProxy：Timer 强持有 target，代理只持 weak owner，
        // 避免 view ↔ timer 相互保活；回调经 assumeIsolated 落回主演员。
        // ⚠️ 与 Carousel 同款闭包替换：strict concurrency 只认「weak owner 类引用」写法。
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

    // MARK: - 差异映射

    /// tone 对应的默认图标：提示类语义。
    private static func defaultIcon(for tone: ComponentTone) -> String {
        switch tone {
        case .neutral:  return "info.circle.fill"
        case .primary:  return "info.circle.fill"
        case .success:  return "checkmark.circle.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .danger:   return "xmark.octagon.fill"
        }
    }

    @objc private func handleClose() {
        onIntent?(.close)
    }
}

// MARK: - Timer 的弱代理

/// Timer 强持有 target：用 NSObject 代理只持 weak owner，避免 NoticeBridgeView ↔ Timer
/// 相互保活。回调落在主 RunLoop，assumeIsolated 让编译器认可「主线程就是主演员」。
/// 拆桥路径：teardown 里先 timer.invalidate() + 置 nil，否则到点空转。
private final class WeakTimerProxy: NSObject {
    private weak var owner: NoticeBridgeView?

    init(_ owner: NoticeBridgeView) {
        self.owner = owner
    }

    @objc func fire() {
        guard let owner else { return }
        MainActor.assumeIsolated {
            owner.autoDismissed()
        }
    }
}