//
//  RadioGroupComponent.swift
//  SwiftBridgeComponents
//
//  单选组 —— 交互组件：纵向排布的一组单选行，选中态由业务回写。
//
//  设计对齐 Segmented 的「重建 + 同步选中」纪律：
//    · 选项集合变化 → 整组重建行（按钮带 tag 指向下标）；
//    · selectedID 变化 → 只刷图标与文案颜色，不重建行（syncSelection）；
//    · 点某行上报 .changed(id)，业务决定选中并回写 selectedID。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    options    → 重建行（数量/文案变化才重建）
//    selectedID → 勾选圈图标 + 文案强调 + 无障碍 value
//    tone       → 选中圈配色（.system 处理同 Chip 组：tone 走主题）
//    isEnabled  → 每行按钮禁用 + 整体 alpha
//  无障碍：每行各自是一个读屏元素（label=文案，value=已选/未选），
//  不做容器单元素 —— 单选组需要逐行朗读才能表达「哪几项可选」。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 单选组的一个选项（纯值）：稳定 id + 展示文案。
public struct RadioOption: Hashable, Sendable {
    /// 选项稳定标识（上报给业务用，不随文案变化）。
    public var id: String
    /// 选项展示文案。
    public var title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// 单选组状态：选项集合 + 当前选中 id + 配色 + 可用性，选中态由业务回写。
public struct RadioGroupState: BridgeState {
    /// 全部选项（顺序即展示顺序）。
    public var options: [RadioOption]
    /// 当前选中的选项 id；nil = 一个都没选。
    public var selectedID: String?
    /// 配色主题：选中圈与强调色。
    public var tone: ComponentTone
    /// 是否可交互；不可用时逐行禁用并整体降透明度。
    public var isEnabled: Bool

    /// 构造单选组状态。
    /// - Parameters:
    ///   - options: 选项集合（顺序即展示顺序）。
    ///   - selectedID: 当前选中 id；默认 nil。
    ///   - tone: 配色主题；默认 .primary。
    ///   - isEnabled: 是否可交互；默认 true。
    public init(options: [RadioOption],
                selectedID: String? = nil,
                tone: ComponentTone = .primary,
                isEnabled: Bool = true) {
        self.options = options
        self.selectedID = selectedID
        self.tone = tone
        self.isEnabled = isEnabled
    }
}

/// 单选组交互意图：选中了哪一项。
public enum RadioGroupIntent: BridgeIntent {
    /// 某选项被点选（带该选项 id）；是否采纳由业务决定并回写 selectedID。
    case changed(String)
}

// MARK: - 桥视图

/// 单选组桥视图：纵向单选行集合，选中态由业务回写驱动。
@MainActor
public final class RadioGroupBridgeView: UIView, BridgeView {

    /// 桥状态类型：选项集合 + 选中 id 等。
    public typealias State = RadioGroupState
    /// 桥意图类型：选中了哪一项。
    public typealias Intent = RadioGroupIntent

    /// 意图上抛回调：某选项被点选。
    public var onIntent: ((RadioGroupIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）。nil = 回落全局 `ComponentTheme.current`。
    public var theme: (any BridgeTheme)?
    /// 上次解析生效的主题缓存：变化时强制重绘颜色（themeChanged）。
    private var cachedTheme: ComponentTheme?

    let rowsStack = UIStackView()
    /// internal（非 private）：留给 @testable 冒烟测试断言行数与触发点按。
    internal private(set) var optionButtons: [UIButton] = []
    private var cached: RadioGroupState?

    /// 构造组件：搭好纵向行栈（行在 apply 里按 options 重建）。
    /// - Parameters:
    ///   - frame: 初始 frame。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        rowsStack.chain()
            .axis(.vertical)
            .distribution(.fillEqually)
            .spacing(0)
            .added(to: self)
            .build()

        rowsStack.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：行高固定 40 × 行数；宽度交由外部布局。
    override public var intrinsicContentSize: CGSize {
        let count = cached?.options.count ?? 0
        return CGSize(width: UIView.noIntrinsicMetric, height: ComponentMetrics.radioRowHeight() * CGFloat(count))
    }

    // MARK: - BridgeView

    /// 应用最新状态：选项变化重建行；选中/色调变化只刷图标；可用性逐行下发。
    /// - Parameters:
    ///   - state: 最新的单选组状态。
    public func apply(_ state: RadioGroupState) {
        // 主题解析：每桥覆盖优先，否则回落全局 current；themeChanged 时强制重绘颜色
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if prev?.options != state.options {
            rebuildRows(state.options)
        }
        if themeChanged || prev?.tone != state.tone || prev?.selectedID != state.selectedID {
            syncSelection(theme: theme)
        }
        if prev?.isEnabled != state.isEnabled {
            alpha = state.isEnabled ? 1 : 0.5
        }
        // 行按钮的可用性跟随当前快照（重建后也回到正确状态）
        optionButtons.forEach { $0.isEnabled = state.isEnabled }
    }

    /// 拆桥：摘按钮 target、清事件通道（幂等，dismantle 与 deinit 两条路径都可能触发）。
    public func teardown() {
        for button in optionButtons {
            button.removeTarget(self, action: nil, for: .allEvents)
        }
        onIntent = nil
    }

    // MARK: - 行装配

    /// 重建整组行：清空旧行后按 options 逐行搭「勾选圈 + 文案」按钮。
    private func rebuildRows(_ options: [RadioOption]) {
        for view in rowsStack.arrangedSubviews {
            rowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        optionButtons.removeAll()

        for (index, option) in options.enumerated() {
            let button = UIButton(type: .custom)

            let icon = UIImageView()
            icon.chain()
                .contentMode(.scaleAspectFit)
                .added(to: button)

            let title = UILabel()
            title.chain()
                .font(ComponentTypography.fieldFont())
                .text(option.title)
                .textColor(.label)
                .numberOfLines(1)
                .added(to: button)

            // 单行读屏元素：label = 文案，value = 已选/未选（by apply 的 syncSelection）
            button.isAccessibilityElement = true
            button.accessibilityTraits = [.button]
            button.tag = index
            // ⚠️ 不能走 ChainKit `.added(to: rowsStack)`：那是普通 addSubview，
            // UIStackView 不会排布 → 按钮 0×0 不可点（demo11 实测复现）。
            // 必须 `addArrangedSubview` 让 fillEqually 分配行高与宽度。
            button.chain()
                .target(self, action: #selector(handleOptionTap(_:)), for: .touchUpInside)
                .autolayout()
                .build()
            rowsStack.addArrangedSubview(button)

            icon.snp.makeConstraints { make in
                make.leading.equalTo(button).offset(16)
                make.centerY.equalTo(button)
                make.width.height.equalTo(ComponentMetrics.radioIconSize())
            }
            title.snp.makeConstraints { make in
                make.leading.equalTo(button).offset(46)
                make.trailing.equalTo(button).offset(-16)
                make.centerY.equalTo(button)
            }

            optionButtons.append(button)
        }
        invalidateIntrinsicContentSize()
    }

    // MARK: - 差异映射

    /// 同步选中呈现：勾选圈图标按「选中 id」「色调」分档配色，文案强调同步。
    private func syncSelection(theme: ComponentTheme) {
        guard let state = cached else { return }
        let tint = theme.color(for: state.tone)

        for (index, button) in optionButtons.enumerated() {
            guard state.options.indices.contains(index) else { continue }
            let isCurrent = state.options[index].id == state.selectedID
            let icon = button.subviews.compactMap { $0 as? UIImageView }.first
            let title = button.subviews.compactMap { $0 as? UILabel }.first

            icon?.image = UIImage(systemName: isCurrent ? "largecircle.fill.circle" : "circle")
            icon?.tintColor = isCurrent ? tint : .tertiaryLabel
            title?.textColor = isCurrent ? .label : .secondaryLabel
            title?.font = ComponentTypography.fieldFont()
            if isCurrent {
                title?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            }
            button.accessibilityLabel = state.options[index].title
            button.accessibilityValue = isCurrent ? "已选" : "未选"
        }
    }

    // MARK: - 事件

    @objc private func handleOptionTap(_ sender: UIButton) {
        guard let state = cached,
              state.options.indices.contains(sender.tag) else { return }
        onIntent?(.changed(state.options[sender.tag].id))
    }

    // MARK: - 测试钩子

    /// internal 测试钩子：直连第 index 行的点按逻辑（无头模拟器不派发 UIControl
    /// target-action，与 Overlay 组件 fire-* 同模式；生产路径按钮 target = 同一 handler）。
    internal func fireOptionTap(at index: Int) {
        guard optionButtons.indices.contains(index) else { return }
        handleOptionTap(optionButtons[index])
    }
}