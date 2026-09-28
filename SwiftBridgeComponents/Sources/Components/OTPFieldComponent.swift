//
//  OTPFieldComponent.swift
//  SwiftBridgeComponents
//
//  验证码输入框 —— 表单组件：一个隐藏 UITextField 驱动 N 个格子的显示层。
//
//  教学点：
//    1. **隐藏域单点输入责任**：键盘/焦点/粘贴都发生在唯一 first responder 上，
//       N 个格子只是显示层 → 没有「逐个管理焦点」的竞态和键盘闪跳。
//    2. **整框粘贴自动分格**：数字键盘也能粘贴，多字符 replacement 自然铺进各格。
//    3. **满格 completion**：全文满 codeLength → 收键盘 + 只上报一次 .completed。
//    4. **输入保护**（Demo03 正解）：apply 里只在「未在编辑」时回写，不抢焦点不打断输入。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    codeLength → 重建格子栈（宽度随之变化，intrinsic 重算）
//    value      → 输入保护回写（未聚焦才写）+ 重渲染 + 重置 lastReported
//    tone       → 格子边框（当前格高亮）+ 字符色
//    isSecure   → 每格渲染遮盖号「●」（isSecureTextEntry 由隐藏域实现，格子只负责显示层）
//    isEnabled  → 格子整体降透明度 + 关隐藏域（不可聚焦 = 收键盘）
//  隐藏域 delegate 收口：shouldChange 限长（超限直接拒绝）、selection 变化重渲染 + 去重上报。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 验证码输入框的展示状态：格数 + 全文 + 配色 + 遮盖号 + 可用性。
public struct OTPFieldState: BridgeState {
    /// 格子数（init 钳到 4…8）。
    public var codeLength: Int
    /// 当前全文（每格取一位渲染）。
    public var value: String
    /// 配色主题：格内字符色与「当前格」的高亮边框。
    public var tone: ComponentTone
    /// 是否以遮盖号显示（验证码也常需要隐藏展示）。
    public var isSecure: Bool
    /// 是否可交互。
    public var isEnabled: Bool

    /// 构造验证码输入框状态。
    /// - Parameters:
    ///   - codeLength: 格子数；默认 6。init 里钳到 4…8。
    ///   - value: 当前全文；默认 ""。
    ///   - tone: 配色主题；默认 .primary。
    ///   - isSecure: 是否遮盖显示；默认 false。
    ///   - isEnabled: 是否可交互；默认 true。
    public init(codeLength: Int = 6,
                value: String = "",
                tone: ComponentTone = .primary,
                isSecure: Bool = false,
                isEnabled: Bool = true) {
        // 格子数留个业务合理区间（纯函数，可单测）
        self.codeLength = min(max(codeLength, 4), 8)
        self.value = value
        self.tone = tone
        self.isSecure = isSecure
        self.isEnabled = isEnabled
    }
}

/// 验证码输入框交互意图：内容变化 / 满格完成。
public enum OTPFieldIntent: BridgeIntent {
    /// 全文变化（去重后上报当前全文）。
    case changed(String)
    /// 满格后自动回调一次（伴随收键盘）。
    case completed(String)
}

// MARK: - 桥视图

/// 验证码输入框桥视图：隐藏域 + N 格显示层，delegate 单点收口。
@MainActor
public final class OTPFieldBridgeView: UIView, BridgeView, UITextFieldDelegate {

    /// 桥状态类型：格数 + 全文等。
    public typealias State = OTPFieldState
    /// 桥意图类型：全文变化 / 满格完成。
    public typealias Intent = OTPFieldIntent

    /// 意图上抛回调：全文变化 / 满格完成。
    public var onIntent: ((OTPFieldIntent) -> Void)?

    /// internal（非 private）：留给 @testable 冒烟测试校验 apply 回写用。
    let field = UITextField()
    private var boxes: [UIView] = []
    private var charLabels: [UILabel] = []
    /// 上报去重水印：全文没变就不上报，防闭环。
    private var lastReported: String?
    /// 满格完成只回调一次：再填满（清空后重输）会重新触发。
    private var completionArchived = false
    private var cached: OTPFieldState?
    /// 上次生效主题：换肤重放 apply 时强制重渲染所有格子。
    private var cachedTheme: ComponentTheme?

    /// 构造组件：搭好透明隐藏域与初始格子栈。
    /// - Parameters:
    ///   - frame: 初始 frame。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        // 隐藏域：不可见但可聚焦 —— 键盘/焦点/粘贴全部收口在它身上
        field.chain()
            .delegate(self)
            .keyboardType(.numberPad)
            .autocorrectionType(.no)
            .borderStyle(.none)
            .textColor(.clear)
            .tintColor(.clear)          // 光标不可见
            .backgroundColor(.clear)
            .added(to: self)
        // 短信验证码自动填充（one time code）：ChainKit 无此方法，直写
        field.textContentType = .oneTimeCode

        // 无障碍：只暴露隐藏域一个聚焦元素（格子/容器不设元素，避免抢焦点、挡数字键盘）
        field.isAccessibilityElement = true
        field.accessibilityLabel = "验证码"

        field.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        rebuildBoxes(count: 6)
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：宽随格数（N 格 + (N-1) 间距），高为盒高。
    override public var intrinsicContentSize: CGSize {
        let count = cached?.codeLength ?? 6
        let size = ComponentMetrics.otpBoxSize()
        let spacing = ComponentMetrics.otpBoxSpacing()
        let width = CGFloat(count) * size + CGFloat(max(count - 1, 0)) * spacing
        return CGSize(width: width, height: size)
    }

    // MARK: - BridgeView

    /// 应用最新状态：格数差异重建栈，文本差异在输入保护下回写。
    /// - Parameters:
    ///   - state: 最新的验证码输入框状态。
    public func apply(_ state: OTPFieldState) {
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if prev?.codeLength != state.codeLength {
            rebuildBoxes(count: state.codeLength)
        }

        // ⚠️ 输入保护：正在编辑时绝不回写（否则每次 apply 都抢光标、打断输入）
        if !field.isFirstResponder, field.text != state.value {
            field.text = state.value
            lastReported = state.value
            renderBoxes()
        }
        // 主题化：换肤或色调/遮盖变化 → 重渲染所有格子（renderBoxes 不必然每次 apply 被调）
        if themeChanged || prev?.tone != state.tone || prev?.isSecure != state.isSecure {
            renderBoxes()
        }
        if field.isEnabled != state.isEnabled {
            field.isEnabled = state.isEnabled
            if !state.isEnabled { field.resignFirstResponder() }
            renderBoxes()
        }
    }

    /// 拆桥：摘代理、移除格子层、清意图回调。
    public func teardown() {
        field.delegate = nil
        field.removeTarget(self, action: nil, for: .allEvents)
        for box in boxes { box.removeFromSuperview() }
        boxes.removeAll()
        charLabels.removeAll()
        onIntent = nil
    }

    // MARK: - UITextFieldDelegate（限长 / 渲染 / 上报）

    /// 超限输入直接拒绝：比回写截断干净，光标不跳、不多打一轮回调。
    public func textField(_ textField: UITextField,
                          shouldChangeCharactersIn range: NSRange,
                          replacementString string: String) -> Bool {
        guard let codeLength = cached?.codeLength else { return true }
        let newText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? string
        return newText.count <= codeLength
    }

    /// 选择/文本变化（用户输入与程序化回写都会走到）：重渲染 + 去重上报 + 满格完成。
    public func textFieldDidChangeSelection(_ textField: UITextField) {
        renderBoxes()
        let current = textField.text ?? ""
        guard lastReported != current else { return }   // 光标移动 / 已被 apply 同步的值 → 不上报
        lastReported = current
        onIntent?(.changed(current))

        let codeLength = cached?.codeLength ?? 0
        if !current.isEmpty, current.count == codeLength, !completionArchived {
            completionArchived = true
            textField.resignFirstResponder()            // 满格自动收键盘
            onIntent?(.completed(current))
        } else if current.count != codeLength {
            completionArchived = false                 // 重新变不满 → 下次满格可再上报
        }
    }

    // MARK: - 显示层

    /// 按当前格数重建盒子栈：SnapKit 水平排布等宽等距，保持居中。
    private func rebuildBoxes(count: Int) {
        for box in boxes { box.removeFromSuperview() }
        boxes.removeAll()
        charLabels.removeAll()

        let size = ComponentMetrics.otpBoxSize()
        let spacing = ComponentMetrics.otpBoxSpacing()
        var prev: UIView?
        for _ in 0..<max(count, 0) {
            let box = UIView()
            box.chain()
                .cornerRadius(size / 4)
                .borderWidth(1)
                .borderColor(UIColor.separator)
                .backgroundColor(.clear)
                .added(to: self)

            let label = UILabel()
            label.chain()
                .font(ComponentTypography.otpFont())
                .textAlignment(.center)
                .added(to: box)
            label.snp.makeConstraints { make in
                make.edges.equalTo(box)
            }

            box.snp.makeConstraints { make in
                make.width.height.equalTo(size)
                make.centerY.equalTo(self)
                if let prev {
                    make.leading.equalTo(prev.snp.trailing).offset(spacing)
                } else {
                    make.leading.equalTo(self)
                }
            }

            prev = box
            boxes.append(box)
            charLabels.append(label)
        }
        // 隐藏域必须保持在最上层：后加的格子会盖住它 → 移回最前保证可点聚焦
        bringSubviewToFront(field)
        renderBoxes()
        invalidateIntrinsicContentSize()
    }

    /// 全文分格渲染：前 N 位各自落格，当前待填格高亮边框。
    private func renderBoxes() {
        let text = field.text ?? ""
        let count = boxes.count
        // 主题化：字符/边框/高亮底色全部走 resolvedTheme()
        let toneColor = resolvedTheme().color(for: cached?.tone ?? .primary)
        let softColor = resolvedTheme().softBackground(for: cached?.tone ?? .primary)
        let showsDot = cached?.isSecure ?? false
        let dimmed = (cached?.isEnabled ?? true) ? 1 : 0.4

        for i in 0..<count {
            let box = boxes[i]
            let label = charLabels[i]
            let isNext = i == text.count && text.count < count
            var ch = ""
            if i < text.count {
                ch = String(text[text.index(text.startIndex, offsetBy: i)])
                if showsDot { ch = "●" }
            }
            label.text = ch
            label.textColor = toneColor
            label.font = ComponentTypography.otpFont()
            box.layer.borderColor = isNext ? toneColor.cgColor : UIColor.separator.cgColor
            box.backgroundColor = isNext ? softColor : .clear
            box.alpha = dimmed
        }
    }
}