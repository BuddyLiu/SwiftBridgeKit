//
//  BottomSheetComponent.swift
//  SwiftBridgeComponents
//
//  底部选择表（设施：弹层容器三组件之三）。
//
//  用法（配合 overlayPresent 门面，options 里 placement = .bottom）：
//    @State sheet = BottomSheetState(title: "选择颜色", rows: [.init(id: "red", title: "红", selected: true)], ...)
//    .overlayPresent(isPresented: $show, state: sheet, makeView: { BottomSheetBridgeView() },
//                    options: .init(placement: .bottom), onIntent: { ... })
//
//  交互语义（教学点，与 Dialog/ActionSheet 的「点即关」刻意区分）：
//    · 行被点：只抛 .changed(row.id)，**不自动关** —— 业务决定（比如让用户连续选择，
//      或选完再统一关）；选中的勾选态也由业务经 state 控制；
//    · 取消钮：抛 .canceled 并请求关闭；
//    · 拖拽 / 点蒙层关闭交给容器（OverlayManager 统一收口）。
//

import UIKit
import SnapKit
import SwiftBridgeKit

// MARK: - 契约层

/// 底部选择表的行。
public struct BottomSheetRow: Hashable {
    public let id: String
    public let title: String
    public let detail: String?
    /// SF Symbol 名（行首小图标）。
    public let leadingIcon: String?
    /// 是否显示行尾勾选。
    public let selected: Bool

    public init(id: String, title: String, detail: String? = nil,
                leadingIcon: String? = nil, selected: Bool = false) {
        self.id = id
        self.title = title
        self.detail = detail
        self.leadingIcon = leadingIcon
        self.selected = selected
    }
}

/// 底部选择表的 State：可选标题 + 行列表 + 是否提供取消区。
public struct BottomSheetState: BridgeState {
    public var title: String?
    public var rows: [BottomSheetRow]
    public var cancelAvailable: Bool

    public init(title: String? = nil, rows: [BottomSheetRow] = [], cancelAvailable: Bool = true) {
        self.title = title
        self.rows = rows
        self.cancelAvailable = cancelAvailable
    }
}

/// 底部选择表交互意图。
public enum BottomSheetIntent: BridgeIntent {
    /// 轻点某行（**不自动关**，由业务在 onIntent 里决定是否收起）。
    case changed(String)
    /// 轻点取消（请求关闭见 onRequestDismiss 通道）。
    case canceled
}

// MARK: - 桥视图

/// 底部选择表桥视图：拖拽把手区 + 标题 + 行列表 + 可选取消区。
@MainActor
public final class BottomSheetBridgeView: UIView, BridgeView, OverlayDismissChannel {

    /// 关联的契约状态类型。
    public typealias State = BottomSheetState
    /// 关联的契约意图类型。
    public typealias Intent = BottomSheetIntent

    public var onIntent: ((BottomSheetIntent) -> Void)?
    /// 取消钮被点时请求宿主收起弹层。
    public var onRequestDismiss: (() -> Void)?

    private let titleLabel = UILabel()
    /// 行按钮容器（internal：@testable 测试按 UX 路径触发按钮事件）。
    internal let rowsStack = UIStackView()
    /// 取消区按钮（internal：同上）。
    internal let cancelButton = UIButton(type: .system)
    private var cancelHeightConstraint: Constraint?
    private var rowButtons: [UIButton] = []
    private var rowsByButton: [UIButton: BottomSheetRow] = [:]
    private var cached: BottomSheetState?
    private var cachedTheme: ComponentTheme?

    /// 以 frame 创建，并完成把手留白、标题区、行区与取消区的构建。
    override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground

        // 顶部留白留给容器画的拖拽把手（handle bar）
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        addSubview(titleLabel)

        rowsStack.axis = .vertical
        rowsStack.spacing = 0
        addSubview(rowsStack)

        cancelButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.backgroundColor = .systemGray6
        cancelButton.layer.cornerRadius = 12
        cancelButton.clipsToBounds = true
        cancelButton.addTarget(self, action: #selector(handleCancelTap), for: .touchUpInside)
        addSubview(cancelButton)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(self).offset(20)
            make.leading.equalTo(self).offset(20)
            make.trailing.equalTo(self).offset(-20)
        }
        rowsStack.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalTo(self).inset(8)
        }
        cancelButton.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(rowsStack.snp.bottom).offset(12)
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
        let rowsCount = CGFloat(cached?.rows.count ?? 0)
        let rowsH = rowsCount * 56
        let cancelBand: CGFloat = cached?.cancelAvailable == true ? 12 + 52 : 0
        let height = 20 + titleH + 8 + rowsH + 16 + cancelBand
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    // MARK: - BridgeView

    /// 按状态差异更新：标题/行/取消区只在差异时刷新，换肤重放靠 themeChanged。
    public func apply(_ state: BottomSheetState) {
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if themeChanged || prev?.title != state.title {
            titleLabel.text = state.title
            titleLabel.isHidden = state.title?.isEmpty != false
        }
        if themeChanged || prev?.rows != state.rows {
            rebuildRows(state.rows)
        }
        if themeChanged || prev?.cancelAvailable != state.cancelAvailable {
            cancelButton.isHidden = !state.cancelAvailable
            cancelHeightConstraint?.update(offset: state.cancelAvailable ? 52 : 0)
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

    /// 重建行区（行列表变化或换肤时调用）。
    private func rebuildRows(_ rows: [BottomSheetRow]) {
        for button in rowButtons {
            rowsStack.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        rowButtons.removeAll()
        rowsByButton.removeAll()

        for row in rows {
            let button = makeRowButton(row)
            rowsStack.addArrangedSubview(button)
            rowButtons.append(button)
            rowsByButton[button] = row
        }
    }

    /// 构建一行：「图标 + 标题(+副标题) + 行尾勾选」的透明按钮。
    private func makeRowButton(_ row: BottomSheetRow) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = .clear
        button.snp.makeConstraints { make in
            make.height.equalTo(56)
        }

        if let icon = row.leadingIcon {
            let iconView = UIImageView(image: UIImage(systemName: icon))
            iconView.tintColor = .secondaryLabel
            iconView.contentMode = .scaleAspectFit
            button.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.leading.equalTo(button).offset(16)
                make.centerY.equalTo(button)
                make.size.equalTo(22)
            }
        }

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2
        let title = UILabel()
        title.text = row.title
        title.font = .systemFont(ofSize: 16)
        title.textColor = .label
        textStack.addArrangedSubview(title)
        if let detail = row.detail {
            let detailLabel = UILabel()
            detailLabel.text = detail
            detailLabel.font = .systemFont(ofSize: 13)
            detailLabel.textColor = .secondaryLabel
            textStack.addArrangedSubview(detailLabel)
        }
        button.addSubview(textStack)
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(button).offset(row.leadingIcon == nil ? 16 : 46)
            make.trailing.equalTo(button).offset(-44)
            make.centerY.equalTo(button)
        }

        if row.selected {
            let check = UIImageView(image: UIImage(systemName: "checkmark"))
            check.tintColor = .tintColor
            check.contentMode = .scaleAspectFit
            button.addSubview(check)
            check.snp.makeConstraints { make in
                make.trailing.equalTo(button).offset(-16)
                make.centerY.equalTo(button)
                make.size.equalTo(20)
            }
        }

        // 无障碍：整行是单一按钮元素，label = 标题(+副标题)，value = 已选择态
        button.isAccessibilityElement = true
        button.accessibilityTraits = [.button]
        button.accessibilityLabel = row.detail.map { "\(row.title)，\($0)" } ?? row.title
        if row.selected { button.accessibilityValue = "已选择" }

        button.addTarget(self, action: #selector(handleRowTap(_:)), for: .touchUpInside)
        return button
    }

    // MARK: - 交互

    /// 供测试按 UX 路径触发行点击（无头测试无法 sendActions，见 fireDimTap 注释）。
    internal func fireRowTap(at index: Int) {
        guard rowButtons.indices.contains(index) else { return }
        handleRowTap(rowButtons[index])
    }

    /// 供测试触发取消区（同上）。
    internal func fireCancelTap() {
        handleCancelTap()
    }

    @objc private func handleRowTap(_ sender: UIButton) {
        guard let row = rowsByButton[sender] else { return }
        // 只上报，不自动关：业务决定是否连选后由 OnIntent 里收起
        onIntent?(.changed(row.id))
    }

    @objc private func handleCancelTap() {
        onIntent?(.canceled)
        onRequestDismiss?()
    }
}