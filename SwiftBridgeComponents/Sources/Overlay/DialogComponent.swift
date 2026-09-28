//
//  DialogComponent.swift
//  SwiftBridgeComponents
//
//  居中对话框（设施：弹层容器三组件之一）。
//
//  用法（配合 overlayPresent 门面）：
//    @State dialog = DialogState(title: "删除？", actions: [.init(id: "ok", title: "删除", style: .danger)])
//    .overlayPresent(isPresented: $show, state: dialog, makeView: { DialogBridgeView() },
//                    onIntent: { if case .tapped(let a) = $0 { ... } })
//
//  交互语义（教学点）：
//    · 任何动作用于：先抛 .tapped(action) 再走 onRequestDismiss —— 业务清 state 与容器自关幂等；
//    · 右上角关闭按钮同样先抛 .close 再请求关闭；
//    · 显隐不归组件管：组件只管「上报 + 请求关闭」，收不收由业务/宿主定。
//
//  主题化：按钮按 style → theme.buttonColors(for:) 渲染（每桥覆盖可换皮肤）；
//  标题/正文用系统语义色（自动暗黑），保持「游离系统色字面量不动」的约定。
//

import UIKit
import SnapKit
import SwiftBridgeKit

// MARK: - 契约层

/// 对话框动作项。
public struct DialogAction: Hashable {
    public let id: String
    /// 按钮文案。
    public let title: String
    /// 按钮样式（决定颜色，走主题调色板）。
    public let style: ButtonStyle

    public init(id: String, title: String, style: ButtonStyle = .primary) {
        self.id = id
        self.title = title
        self.style = style
    }
}

/// 居中对话框的 State：标题/正文/右上角关闭按钮显隐 + 动作列表。
public struct DialogState: BridgeState {
    public var title: String
    public var message: String?
    /// 是否隐藏右上角关闭按钮。
    public var hideCloseButton: Bool
    public var actions: [DialogAction]

    public init(title: String, message: String? = nil,
                hideCloseButton: Bool = false, actions: [DialogAction] = []) {
        self.title = title
        self.message = message
        self.hideCloseButton = hideCloseButton
        self.actions = actions
    }
}

/// 对话框交互意图。
public enum DialogIntent: BridgeIntent {
    /// 轻点某个动作（触发请求关闭见 onRequestDismiss 通道）。
    case tapped(DialogAction)
    /// 轻点右上角关闭按钮。
    case close
}

// MARK: - 桥视图

/// 居中对话框桥视图：标题 + 正文 + 动作按钮区 + 可选关闭按钮。
@MainActor
public final class DialogBridgeView: UIView, BridgeView, OverlayDismissChannel {

    /// 关联的契约状态类型。
    public typealias State = DialogState
    /// 关联的契约意图类型。
    public typealias Intent = DialogIntent

    public var onIntent: ((DialogIntent) -> Void)?
    /// 动作/关闭被点时请求宿主收起弹层。
    public var onRequestDismiss: (() -> Void)?

    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    /// 动作按钮容器（internal：@testable 测试要按 UX 路径触发按钮事件）。
    internal let actionsStack = UIStackView()
    private var actionButtons: [UIButton] = []
    private var actionByButton: [UIButton: DialogAction] = [:]
    private var cached: DialogState?
    private var cachedTheme: ComponentTheme?

    /// 以 frame 创建，并完成卡片背景、标题/正文/关闭钮/动作区的构建。
    override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        addSubview(titleLabel)

        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        addSubview(messageLabel)

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        addSubview(closeButton)

        actionsStack.axis = .vertical
        actionsStack.spacing = 8
        addSubview(actionsStack)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(self).offset(24)
            make.leading.equalTo(self).offset(20)
            make.trailing.equalTo(self).offset(-20)
        }
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalTo(titleLabel)
        }
        actionsStack.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(messageLabel.snp.bottom).offset(16)
            make.leading.trailing.equalTo(self).inset(16)
            make.bottom.equalTo(self).offset(-16)
        }
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(self).offset(8)
            make.trailing.equalTo(self).offset(-8)
            make.size.equalTo(28)
        }
    }

    /// `NSCoding` 初始化器不可用：组件仅支持编程式创建（`init(frame:)`）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固定内容尺寸：宽 300，高按内容估算（标题/正文/动作数，驱动容器卡片位布局）。
    override public var intrinsicContentSize: CGSize {
        let titleH: CGFloat = cached?.title.isEmpty == false ? 28 : 0
        let hasMessage = cached?.message?.isEmpty == false
        let messageH: CGFloat = hasMessage ? 40 : 0
        let actionsCount = CGFloat(cached?.actions.count ?? 0)
        let actionsH = actionsCount * 44 + max(actionsCount - 1, 0) * 8
        let height = 24 + titleH + (hasMessage ? 8 : 0) + messageH + 16 + actionsH + 16 + 4
        return CGSize(width: 300, height: height)
    }

    // MARK: - BridgeView

    /// 按状态差异更新：标题/正文/关闭钮/动作区只在差异时刷新，换肤重放靠 themeChanged。
    public func apply(_ state: DialogState) {
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if themeChanged || prev?.title != state.title {
            titleLabel.text = state.title
        }
        if themeChanged || prev?.message != state.message {
            messageLabel.text = state.message
            messageLabel.isHidden = state.message?.isEmpty != false
        }
        if themeChanged || prev?.hideCloseButton != state.hideCloseButton {
            closeButton.isHidden = state.hideCloseButton
        }
        if themeChanged || prev?.actions != state.actions {
            rebuildActions(state.actions, theme: theme)
        }
        if themeChanged {
            // 文字用系统语义色（自动适配暗黑）；按钮在 rebuild 里已按主题重上色
            titleLabel.textColor = .label
            messageLabel.textColor = .secondaryLabel
            closeButton.tintColor = theme.color(for: .neutral)
        }
    }

    /// 尽力清理：断开两条通道（容器收掉后不再向业务送达）。
    public func teardown() {
        onIntent = nil
        onRequestDismiss = nil
    }

    // MARK: - 差异映射

    /// 重建动作按钮区（动作列表变化或换肤时调用）。
    private func rebuildActions(_ actions: [DialogAction], theme: ComponentTheme) {
        for button in actionButtons {
            actionsStack.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        actionButtons.removeAll()
        actionByButton.removeAll()

        for action in actions {
            let button = UIButton(type: .system)
            button.setTitle(action.title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            let colors = theme.buttonColors(for: action.style)
            button.backgroundColor = colors.background
            button.setTitleColor(colors.foreground, for: .normal)
            button.layer.cornerRadius = 10
            button.clipsToBounds = true
            button.addTarget(self, action: #selector(handleActionTap(_:)), for: .touchUpInside)
            actionsStack.addArrangedSubview(button)
            button.snp.makeConstraints { make in
                make.height.equalTo(44)
            }
            actionButtons.append(button)
            actionByButton[button] = action
        }
    }

    // MARK: - 交互

    /// 供测试按 UX 路径触发动作点击（无头测试无法 sendActions，见 fireDimTap 注释）。
    internal func fireActionTap(at index: Int) {
        guard actionButtons.indices.contains(index) else { return }
        handleActionTap(actionButtons[index])
    }

    /// 供测试触发右上角关闭（同上）。
    internal func fireCloseTap() {
        handleClose()
    }

    @objc private func handleActionTap(_ sender: UIButton) {
        guard let action = actionByButton[sender] else { return }
        // 先抛意图再请求关闭：业务清 state 与容器自关幂等，重合计也安全
        onIntent?(.tapped(action))
        onRequestDismiss?()
    }

    @objc private func handleClose() {
        onIntent?(.close)
        onRequestDismiss?()
    }
}