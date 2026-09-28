//
//  ActionSheetComponent.swift
//  SwiftBridgeComponents
//
//  底部动作表（设施：弹层容器三组件之二）。
//
//  用法（配合 overlayPresent 门面，options 里 placement = .bottom）：
//    @State sheet = ActionSheetState(title: "导出", items: [.init(id: "pdf", title: "存为 PDF"), ...])
//    .overlayPresent(isPresented: $show, state: sheet, makeView: { ActionSheetBridgeView() },
//                    options: .init(placement: .bottom), onIntent: { ... })
//
//  交互语义：
//    · 任何项（含取消）被点：先抛 .tapped(item) 再请求关闭；
//    · item.tone nil = 中性文字（.label），非 nil = 主题 tone 色；
//    · item.cancel 只是样式标记，决定是否渲染为「独立取消区」。
//

import UIKit
import SnapKit
import SwiftBridgeKit

// MARK: - 契约层

/// 动作表单项。
public struct ActionSheetItem: Hashable {
    public let id: String
    public let title: String
    /// 文字色调；nil = 中性（.label）。
    public let tone: ComponentTone?
    /// 是否为取消项（独立区样式）。
    public let cancel: Bool

    public init(id: String, title: String, tone: ComponentTone? = nil, cancel: Bool = false) {
        self.id = id
        self.title = title
        self.tone = tone
        self.cancel = cancel
    }
}

/// 底部动作表的 State：可选标题/正文 + 动作列表。
public struct ActionSheetState: BridgeState {
    public var title: String?
    public var message: String?
    public var items: [ActionSheetItem]

    public init(title: String? = nil, message: String? = nil, items: [ActionSheetItem] = []) {
        self.title = title
        self.message = message
        self.items = items
    }
}

/// 动作表交互意图。
public enum ActionSheetIntent: BridgeIntent {
    /// 轻点某个项（触发请求关闭见 onRequestDismiss 通道）。
    case tapped(ActionSheetItem)
}

// MARK: - 桥视图

/// 底部动作表桥视图：标题区 + 动作项列表 + 独立取消区。
@MainActor
public final class ActionSheetBridgeView: UIView, BridgeView, OverlayDismissChannel {

    /// 关联的契约状态类型。
    public typealias State = ActionSheetState
    /// 关联的契约意图类型。
    public typealias Intent = ActionSheetIntent

    public var onIntent: ((ActionSheetIntent) -> Void)?
    /// 任一项（含取消）被点时请求宿主收起弹层。
    public var onRequestDismiss: (() -> Void)?

    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    /// 动作项容器（internal：@testable 测试按 UX 路径触发按钮事件）。
    internal let itemsStack = UIStackView()
    /// 独立取消区按钮（internal：同上）。
    internal let cancelButton = UIButton(type: .system)
    private var cancelHeightConstraint: Constraint?
    private var cancelByButton: ActionSheetItem?
    private var itemButtons: [UIButton] = []
    private var itemByButton: [UIButton: ActionSheetItem] = [:]
    private var cached: ActionSheetState?
    private var cachedTheme: ComponentTheme?

    /// 以 frame 创建，并完成标题区、动作区与取消区的构建。
    override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        addSubview(titleLabel)

        messageLabel.font = .systemFont(ofSize: 13)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        addSubview(messageLabel)

        itemsStack.axis = .vertical
        itemsStack.spacing = 0
        addSubview(itemsStack)

        cancelButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.backgroundColor = .systemGray6
        cancelButton.layer.cornerRadius = 12
        cancelButton.clipsToBounds = true
        cancelButton.isHidden = true
        cancelButton.addTarget(self, action: #selector(handleCancelTap), for: .touchUpInside)
        addSubview(cancelButton)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(self).offset(16)
            make.leading.equalTo(self).offset(20)
            make.trailing.equalTo(self).offset(-20)
        }
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.leading.trailing.equalTo(titleLabel)
        }
        itemsStack.snp.makeConstraints { make in
            make.top.equalTo(messageLabel.snp.bottom).offset(8)
            make.leading.trailing.equalTo(self).inset(8)
        }
        cancelButton.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(itemsStack.snp.bottom).offset(12)
            make.leading.trailing.equalTo(self).inset(8)
            cancelHeightConstraint = make.height.equalTo(0).constraint
            make.bottom.equalTo(self).offset(-16)
        }
    }

    /// `NSCoding` 初始化器不可用：组件仅支持编程式创建（`init(frame:)`）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固定内容尺寸：宽交给容器撑满，高按内容估算（驱动 bottom 卡片位）。
    override public var intrinsicContentSize: CGSize {
        let titleH: CGFloat = cached?.title?.isEmpty == false ? 18 : 0
        let messageH: CGFloat = cached?.message?.isEmpty == false ? 18 : 0
        let itemsCount = CGFloat(cached?.items.filter { !$0.cancel }.count ?? 0)
        let itemsH = itemsCount * 52 + max(itemsCount - 1, 0) * 1
        let hasCancel = (cached?.items.contains { $0.cancel }) == true
        let cancelBand: CGFloat = hasCancel ? 12 + 52 : 0
        let height = 16 + titleH + (messageH > 0 ? 6 : 0) + messageH + 8 + itemsH + 16 + cancelBand
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    // MARK: - BridgeView

    /// 按状态差异更新：标题/正文/动作列表只在差异时刷新，换肤重放靠 themeChanged。
    public func apply(_ state: ActionSheetState) {
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if themeChanged || prev?.title != state.title {
            titleLabel.text = state.title
            titleLabel.isHidden = state.title?.isEmpty != false
        }
        if themeChanged || prev?.message != state.message {
            messageLabel.text = state.message
            messageLabel.isHidden = state.message?.isEmpty != false
        }
        if themeChanged || prev?.items != state.items {
            rebuildItems(state.items, theme: theme)
        }
        if themeChanged {
            titleLabel.textColor = .label
            cancelButton.setTitleColor(.label, for: .normal)
        }
    }

    /// 尽力清理：断开两条通道。
    public func teardown() {
        onIntent = nil
        onRequestDismiss = nil
    }

    // MARK: - 差异映射

    /// 重建动作区（列表变化或换肤时调用）：非取消项进入主列表（项间 0.5pt 分隔线），
    /// 取消项渲染到独立取消区。
    private func rebuildItems(_ items: [ActionSheetItem], theme: ComponentTheme) {
        for button in itemButtons {
            itemsStack.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        itemButtons.removeAll()
        itemByButton.removeAll()

        var cancelItem: ActionSheetItem?
        for item in items where item.cancel {
            cancelItem = item
        }
        let regular = items.filter { !$0.cancel }

        for (index, item) in regular.enumerated() {
            if index > 0 {
                let divider = UIView()
                divider.backgroundColor = .separator
                itemsStack.addArrangedSubview(divider)
                divider.snp.makeConstraints { make in
                    make.height.equalTo(0.5)
                }
            }
            let button = makeItemButton(item, theme: theme)
            itemsStack.addArrangedSubview(button)
            itemButtons.append(button)
            itemByButton[button] = item
        }

        // 取消区：有取消项才显（高度在 0 与 52 间切换），标题/色调跟随该项
        if let cancelItem {
            cancelButton.isHidden = false
            cancelHeightConstraint?.update(offset: 52)
            cancelButton.setTitle(cancelItem.title, for: .normal)
            cancelButton.setTitleColor(cancelItem.tone == nil ? .label : theme.color(for: cancelItem.tone!),
                                       for: .normal)
            cancelByButton = cancelItem
        } else {
            cancelButton.isHidden = true
            cancelHeightConstraint?.update(offset: 0)
            cancelByButton = nil
        }
    }

    private func makeItemButton(_ item: ActionSheetItem, theme: ComponentTheme) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(item.title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        let foreground: UIColor = item.tone == nil ? .label : theme.color(for: item.tone!)
        button.setTitleColor(foreground, for: .normal)
        button.addTarget(self, action: #selector(handleItemTap(_:)), for: .touchUpInside)
        button.snp.makeConstraints { make in
            make.height.equalTo(52)
        }
        return button
    }

    // MARK: - 交互

    /// 供测试按 UX 路径触发动作点击（无头测试无法 sendActions，见 fireDimTap 注释）。
    internal func fireItemTap(at index: Int) {
        guard itemButtons.indices.contains(index) else { return }
        handleItemTap(itemButtons[index])
    }

    /// 供测试触发取消区（同上）。
    internal func fireCancelTap() {
        handleCancelTap()
    }

    @objc private func handleItemTap(_ sender: UIButton) {
        guard let item = itemByButton[sender] else { return }
        onIntent?(.tapped(item))
        onRequestDismiss?()
    }

    @objc private func handleCancelTap() {
        guard let item = cancelByButton else { return }
        onIntent?(.tapped(item))
        onRequestDismiss?()
    }
}