//
//  Demo03_FormBridge.swift
//  SwiftBridgeKitDemo
//
//  Demo 03：表单类复杂视图 —— UITextField / UITextView
//
//  这一类视图最大的坑是**双向 text 同步的环**：
//    用户打字 → onIntent → SwiftUI state 更新 → apply 回写 text → 抢光标 / 死循环
//
//  ⚠️ 唯一正确做法（差异映射 + 输入保护）：
//    - apply 里只在「不在编辑中」时回写 text；
//    - 用户正在输入时跳过回写，让输入保持顺滑；
//    - 回写前先与当前值比较，避免无效赋值触发额外通知。
//
//  第二个坑是**生命周期**：TextView 用 delegate 收编辑事件，
//  teardown 时必须断开 delegate（UITextView 的 delegate 虽是 weak，
//  但断连是「拆桥后不再回调」的承诺，必须显式做）。
//

import SwiftUI
import UIKit
import SwiftBridgeKit
import SwiftChainKit
import SnapKit

// MARK: - 契约层

struct FormState: BridgeState {
    var title: String
    var bodyText: String
    var isEnabled: Bool
}

enum FormIntent: BridgeIntent {
    case titleChanged(String)
    case bodyChanged(String)
    case titleSubmitted
}

// MARK: - TextField 桥（用 target-action，不需要 delegate）

final class TextFieldBridgeView: UIView, BridgeView {

    typealias State = FormState
    typealias Intent = FormIntent

    var onIntent: ((FormIntent) -> Void)?

    private let field = UITextField()
    private var lastReported: String?
    private(set) var applyCount = 0
    private(set) var externalWrites = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        // 链式创建：样式 + 两个 target-action 事件归位，一条链收完
        field.chain()
            .borderStyle(.roundedRect)
            .font(.systemFont(ofSize: 15))
            .clearButtonMode(.whileEditing)
            .returnKeyType(.done)
            .target(self, action: #selector(editingChanged), for: .editingChanged)
            .target(self, action: #selector(editingSubmitted), for: .primaryActionTriggered)
            .added(to: self)
            .build()
        field.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(36)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }

    // MARK: - BridgeView

    func apply(_ state: FormState) {
        applyCount += 1

        // ⚠️ 输入保护：正在编辑时绝不回写（否则每次 apply 都抢光标、打断输入）
        if !field.isFirstResponder, field.text != state.title {
            externalWrites += 1
            field.text = state.title
            lastReported = state.title
            print("[FormDemo] 外部回写 title=\(state.title)")
        }
        if field.isEnabled != state.isEnabled { field.isEnabled = state.isEnabled }
    }

    func teardown() {
        field.removeTarget(self, action: nil, for: .allEvents)
        onIntent = nil
    }

    // MARK: - 事件

    @objc private func editingChanged() {
        let current = field.text ?? ""
        // 值没变就不报：既防闭环，也防「外部回写后事件再冒上来」
        guard lastReported != current else { return }
        lastReported = current
        print("[FormDemo] 用户输入 title=\(current)")
        onIntent?(.titleChanged(current))
    }

    @objc private func editingSubmitted() {
        print("[FormDemo] 键盘 done")
        onIntent?(.titleSubmitted)
    }
}

// MARK: - TextView 桥（用 delegate，制造「必须断连」的生命周期场景）

final class TextViewBridgeView: UIView, BridgeView, UITextViewDelegate {

    typealias State = FormState
    typealias Intent = FormIntent

    var onIntent: ((FormIntent) -> Void)?

    private let textView = UITextView()
    private var lastReported: String?
    private(set) var applyCount = 0
    private(set) var externalWrites = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        // 链式创建：delegate + 字体 + 边框圆角；边框收到链上的别名（替代 layer.* 直写）
        textView.chain()
            .delegate(self)
            .font(.systemFont(ofSize: 15))
            .border(1 / UIScreen.main.scale, color: .tertiaryLabel)
            .cornerRadius(6)
            .added(to: self)
            .build()
        textView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 160)
    }

    // MARK: - BridgeView

    func apply(_ state: FormState) {
        applyCount += 1

        // 同样的输入保护：编辑中不回写
        if !textView.isFirstResponder, textView.text != state.bodyText {
            externalWrites += 1
            textView.text = state.bodyText
            lastReported = state.bodyText
            print("[FormDemo] 外部回写 body=\(state.bodyText)")
        }
        if textView.isEditable != state.isEnabled { textView.isEditable = state.isEnabled }
    }

    func teardown() {
        // ⚠️ 最重要的生命周期收口：先断 delegate，再断通道
        textView.delegate = nil
        onIntent = nil
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        let current = textView.text ?? ""
        guard lastReported != current else { return }
        lastReported = current
        print("[FormDemo] 用户输入 body 长度=\(current.count)")
        onIntent?(.bodyChanged(current))
    }
}

// MARK: - Demo 页面

struct Demo03_FormBridgePage: View {

    @State private var title = "初始标题"
    @State private var bodyText = "这是一段初始正文。\n试着点下面的按钮从外部注入。"
    @State private var isEnabled = true
    @State private var lastIntent = "—"

    var body: some View {
        List {
            Section("TextField（target-action 上报 / 输入保护）") {
                BridgeHost(
                    state: FormState(title: title, bodyText: bodyText, isEnabled: isEnabled),
                    makeView: { TextFieldBridgeView() },
                    onIntent: { intent in
                        if case .titleChanged(let v) = intent { title = v }
                        if case .titleSubmitted = intent { lastIntent = "键盘提交" }
                    }
                )
                .frame(height: 48)
                .listRowInsets(EdgeInsets())
            }

            Section("TextView（delegate 上报 / 断连收口）") {
                BridgeHost(
                    state: FormState(title: title, bodyText: bodyText, isEnabled: isEnabled),
                    makeView: { TextViewBridgeView() },
                    onIntent: { intent in
                        if case .bodyChanged(let v) = intent { bodyText = v }
                    }
                )
                .frame(height: 160)
                .listRowInsets(EdgeInsets())
            }

            Section("控制（外部注入，验证「不打断正在编辑」）") {
                Button("外部注入标题：'外部值'") { title = "外部值" }
                Button("外部注入正文：'外部正文'") { bodyText = "外部正文" }
                Toggle("可用", isOn: $isEnabled)
                LabeledContent("最近意图", value: lastIntent)
                Text("自检：先点进输入框打字（控制台出现「用户输入」），再点外部注入按钮\n——正在输入的框不应被回写抢光标；没在输入的框应立刻看到外部值。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("03 · 表单（TextField / TextView）")
    }
}

#Preview {
    NavigationStack { Demo03_FormBridgePage() }
}