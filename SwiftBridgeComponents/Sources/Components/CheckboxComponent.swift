//
//  CheckboxComponent.swift
//  SwiftBridgeComponents
//
//  复选框 —— 交互组件：单个「勾选框 + 文案」行，选中态由业务回写。
//
//  设计对齐 Chip 的「唯一真相」纪律：
//    · 点击只上报 .tapped，是否选中由业务决定并回写 isSelected；
//    · 视图只呈现快照（勾选框填色 + checkmark 显隐 + 文案），绝不就地翻转自己的状态。
//  多选一组 = 业务侧叠几个 CheckboxBridgeView（与 Chip 组一致），组件不发明集合状态。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    title      → 文案 + 无障碍 label
//    isSelected → 勾选框底色 / 边框 / checkmark 显隐 + 无障碍 value
//    tone       → 勾选框填色（仅选中态可见）
//    isEnabled  → 手势开关 + alpha
//  主题：勾选色走上文 resolvedTheme()（每桥 override ?? 全局 current），themeChanged 强制重绘。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 复选框状态：文案 / 选中 / 配色 / 可用性，选中态由业务回写。
public struct CheckboxState: BridgeState {
    /// 复选框左侧文案。
    public var title: String
    /// 选中态。由业务回写驱动，视图不自己翻转。
    public var isSelected: Bool
    /// 配色主题：选中时勾选框底色。
    public var tone: ComponentTone
    /// 是否可交互；不可用时关手势并降到半透明（alpha 0.5）。
    public var isEnabled: Bool

    /// 构造复选框状态。
    /// - Parameters:
    ///   - title: 复选框文案。
    ///   - isSelected: 是否选中；默认 false。
    ///   - tone: 配色主题；默认 .primary。
    ///   - isEnabled: 是否可交互；默认 true。
    public init(title: String,
                isSelected: Bool = false,
                tone: ComponentTone = .primary,
                isEnabled: Bool = true) {
        self.title = title
        self.isSelected = isSelected
        self.tone = tone
        self.isEnabled = isEnabled
    }
}

/// 复选框交互意图：点击。
public enum CheckboxIntent: BridgeIntent {
    /// 复选框被点击；是否选中由业务决定并回写。
    case tapped
}

// MARK: - 桥视图

/// 复选框桥视图：勾选框 + 文案行，点击只上报意图，选中态由业务回写驱动。
@MainActor
public final class CheckboxBridgeView: UIView, BridgeView {

    /// 桥状态类型：文案 / 选中 / 配色 / 可用。
    public typealias State = CheckboxState
    /// 桥意图类型：点击。
    public typealias Intent = CheckboxIntent

    /// 意图上抛回调：点击复选框。
    public var onIntent: ((CheckboxIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）。nil = 回落全局 `ComponentTheme.current`。
    public var theme: (any BridgeTheme)?
    /// 上次解析生效的主题缓存：变化时强制重绘颜色（themeChanged）。
    private var cachedTheme: ComponentTheme?

    /// internal（非 private）：留给 @testable 冒烟测试断言呈现态。
    let box = UIView()
    let checkmark = UIImageView()
    let label = UILabel()
    private let stack = UIStackView()
    private var cached: CheckboxState?

    /// 构造组件：搭好「勾选框 + 文案」水平行与点击手势。
    /// - Parameters:
    ///   - frame: 初始 frame。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        // 无障碍：整行收敛为单个按钮语义的读屏元素（label/value 由 apply 更新）
        isAccessibilityElement = true
        accessibilityTraits = [.button]

        // 勾选框：圆角小方块，选中态整块填主题色，checkmark 白勾居中
        box.chain()
            .clipsToBounds(true)
            .cornerRadius(5)
            .borderWidth(1)
            .borderColor(UIColor.separator)
            .backgroundColor(.clear)
            .autolayout()
            .build()

        checkmark.chain()
            .image(UIImage(systemName: "checkmark"))
            .tintColor(.white)
            .contentMode(.scaleAspectFit)
            .isHidden(true)
            .added(to: box)
            .autolayout()
            .build()

        label.chain()
            .font(ComponentTypography.fieldFont())
            .textColor(.label)
            .textAlignment(.left)
            .numberOfLines(1)
            .autolayout()
            .build()

        // 水平行：勾选框固定 22×22，文案填满剩余宽度；行高由 intrinsic 定
        stack.chain()
            .axis(.horizontal)
            .alignment(.center)
            .spacing(10)
            .arrangedSubviews([box, label])
            .added(to: self)
            .build()

        stack.snp.makeConstraints { make in
            make.top.bottom.equalTo(self)
            make.leading.equalTo(self).offset(16)
            make.trailing.equalTo(self).offset(-16)
        }

        box.snp.makeConstraints { make in
            make.width.height.equalTo(ComponentMetrics.checkboxBoxSize())
        }

        checkmark.snp.makeConstraints { make in
            make.edges.equalTo(box).inset(ComponentMetrics.checkboxBoxSize() * 0.18)
        }

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：行高固定（checkboxRowHeight），宽度交由外部布局。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: ComponentMetrics.checkboxRowHeight())
    }

    // MARK: - BridgeView

    /// 应用最新状态：逐字段差分更新文案 / 勾选呈现 / 可用性。
    /// - Parameters:
    ///   - state: 最新的复选框状态。
    public func apply(_ state: CheckboxState) {
        // 主题解析：每桥覆盖优先，否则回落全局 current；themeChanged 时强制重绘颜色
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if themeChanged || prev?.title != state.title
            || prev?.isSelected != state.isSelected || prev?.tone != state.tone {
            applySelectionStyle(state, theme: theme)
        }
        if prev?.isEnabled != state.isEnabled {
            isUserInteractionEnabled = state.isEnabled
            alpha = state.isEnabled ? 1 : 0.5
        }
    }

    /// 拆桥：清事件通道（幂等，dismantle 与 deinit 两条路径都可能触发）。
    public func teardown() {
        onIntent = nil
    }

    // MARK: - 差异映射

    private func applySelectionStyle(_ state: CheckboxState, theme: ComponentTheme) {
        label.text = state.title
        // 单元素读屏：label = 文案，value = 选中态
        accessibilityLabel = state.title
        accessibilityValue = state.isSelected ? "已选" : "未选"

        let fill = theme.color(for: state.tone)
        if state.isSelected {
            box.backgroundColor = fill
            box.layer.borderColor = fill.cgColor
            checkmark.isHidden = false
        } else {
            box.backgroundColor = .clear
            box.layer.borderColor = UIColor.separator.cgColor
            checkmark.isHidden = true
        }
    }

    // MARK: - 事件

    @objc private func handleTap() {
        onIntent?(.tapped)
    }

    // MARK: - 测试钩子

    /// internal 测试钩子：直连点击逻辑（无头模拟器不派发 UIControl target-action，
    /// 与 Overlay 组件 fire-* 同模式；生产路径手势 = 同一 handler）。
    internal func fireTap() {
        handleTap()
    }
}