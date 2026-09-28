//
//  SearchFieldComponent.swift
//  SwiftBridgeComponents
//
//  搜索框 —— 表单组件：UISearchBar 包装，取消钮 / 回车提交 / 可选防抖上报。
//
//  复刻 Demo03 表单正解 + 本包防抖教学点：
//    1. 输入保护：apply 里仅在「未在编辑」时回写 text（防抢光标）。
//    2. 按 lastReportedText 去重：值没变不上报，防闭环。
//    3. debounceInterval（秒）非空 → 每次键入重排一次性 Timer（私有 owner 型
//       弱代理，strict-concurrency 清白），到点才上报最终文本；nil → 立即。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    text               → 输入保护回写 + 去重基线同步
//    placeholder        → 占位文案
//    tone               → bar tintColor（光标 / 清除 / 取消钮）
//    showsCancelButton  → setShowsCancelButton
//    debounceInterval   → 防抖开关（关掉且有待发文本 → 立即 flush）
//    isEnabled          → isUserInteractionEnabled
//  上行：textChanged / submitted（键盘搜索键）/ cancelTapped（取消钮）。
//
//  ⚠️ 公开类 + UISearchBarDelegate 的代理方法必须显式 public；teardown 断 delegate
//     + invalidate 防抖 Timer，否则拆桥后仍回调。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 搜索框状态：UISearchBar 的契约层描述（文案、占位、色调、取消钮、防抖、可用态）。
/// 各字段在桥视图 apply 内差异映射到 searchBar（见文件头字段清单）；全部属性带有默认值，便于按需覆盖。
public struct SearchFieldState: BridgeState {
    /// 搜索框当前文本。回写受输入保护：桥视图仅在「未在编辑」时写入，避免与用户输入抢光标。
    public var text: String
    /// 占位文案，无输入时显示在搜索框内。
    public var placeholder: String
    /// 主题色：作用于光标、清除钮与取消钮（bar tintColor）。
    public var tone: ComponentTone
    /// 取消钮常显；false = 不显示。
    public var showsCancelButton: Bool
    /// 键入后的延迟上报（秒）；nil = 每次变化立即（仍按值去重）上报。
    public var debounceInterval: Double?
    /// 可用态：false 时禁用搜索框交互。
    public var isEnabled: Bool

    /// 用一个全参调用构建搜索框状态；未指定的参数取默认值。
    ///
    /// - Parameters:
    ///   - text: 初始文本；默认 `""`（无输入）。
    ///   - placeholder: 占位文案；默认 `"搜索"`。
    ///   - tone: 主题色；默认 `.primary`。
    ///   - showsCancelButton: 是否常显取消钮；默认 `true`。
    ///   - debounceInterval: 键入后的延迟上报秒数；默认 `nil`（每次变化立即上报）。
    ///   - isEnabled: 可用态；默认 `true`。
    public init(text: String = "",
                placeholder: String = "搜索",
                tone: ComponentTone = .primary,
                showsCancelButton: Bool = true,
                debounceInterval: Double? = nil,
                isEnabled: Bool = true) {
        self.text = text
        self.placeholder = placeholder
        self.tone = tone
        self.showsCancelButton = showsCancelButton
        self.debounceInterval = debounceInterval
        self.isEnabled = isEnabled
    }
}

/// 搜索框意图：桥视图上行给调用方的用户操作事件。
public enum SearchFieldIntent: BridgeIntent {
    /// 文本变化（按值去重；防抖开启时是「停顿后的最终文本」）。
    case textChanged(String)
    /// 键盘「搜索」键。
    case submitted
    /// 取消钮。
    case cancelTapped
}

// MARK: - 桥视图

/// 搜索框桥视图：UISearchBar 的 BridgeView 包装，把 SearchFieldState 差异映射到 searchBar，
/// 并上行文本变化（含防抖收拢）/ 提交 / 取消三类事件。须在主线程（@MainActor）上创建与使用。
@MainActor
public final class SearchFieldBridgeView: UIView, BridgeView, UISearchBarDelegate {

    /// 本组件对应的状态类型。
    public typealias State = SearchFieldState
    /// 本组件对应的意图类型。
    public typealias Intent = SearchFieldIntent

    /// 上行事件回调：文本变化、提交与取消通过它回传调用方。
    public var onIntent: ((SearchFieldIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）。nil = 回落全局 `ComponentTheme.current`。
    public var theme: (any BridgeTheme)?
    /// 上次解析生效的主题缓存：变化时强制重绘颜色（themeChanged）。
    private var cachedTheme: ComponentTheme?

    /// internal（非 private）：留给 @testable 冒烟测试校验占位 label / 光标色路径用。
    let searchBar = UISearchBar(frame: .zero)
    private var debounceTimer: Timer?
    private var pendingText: String?
    private var lastReportedText: String?
    private var cached: SearchFieldState?

    /// 兼容 frame 初始化：极简样式 + 代理挂接，尺寸由内部 SnapKit 撑满容器。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        // 极简样式 + 代理；尺寸撑满容器走下方 SnapKit
        searchBar.chain()
            .searchBarStyle(.minimal)
            .delegate(self)
            .added(to: self)

        searchBar.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    /// 不参与 storyboard 解码，调用即崩溃；请使用 `init(frame:)` 或桥接器创建。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有尺寸：宽度无约束，高度固定 44pt 保证触摸目标。
    override public var intrinsicContentSize: CGSize {
        // .minimal 风格的搜索条自身无 intrinsic 高度，给 44pt 触摸目标
        CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }

    // MARK: - BridgeView

    /// 应用新状态：按字段逐个与上次缓存比对，仅对变化的字段回写 searchBar。
    /// - Note: 文本回写带输入保护（未在编辑时才写），并会作废挂起的防抖 Timer。
    public func apply(_ state: SearchFieldState) {
        // 主题解析：每桥覆盖优先，否则回落全局 current；themeChanged 时强制重绘颜色
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if prev?.text != state.text {
            // 外部注入：只在未编辑时回写，防抢光标；同时作废挂起的防抖
            debounceTimer?.invalidate()
            debounceTimer = nil
            pendingText = nil
            if !searchBar.isFirstResponder {
                searchBar.text = state.text
                lastReportedText = state.text
            }
        }
        if prev?.placeholder != state.placeholder {
            searchBar.placeholder = state.placeholder
            // 无障碍：用占位文案作搜索框 label（为空时保留系统默认行为）
            searchBar.accessibilityLabel = state.placeholder.isEmpty ? nil : state.placeholder
        }
        if themeChanged || prev?.tone != state.tone {
            searchBar.tintColor = theme.color(for: state.tone)
        }
        if prev?.showsCancelButton != state.showsCancelButton {
            searchBar.setShowsCancelButton(state.showsCancelButton, animated: true)
        }
        if prev?.debounceInterval != state.debounceInterval {
            // 关掉防抖时若有挂起的文本，立即 flush，避免输入丢失
            if state.debounceInterval == nil, debounceTimer != nil {
                flushDebouncedText()
            }
        }
        if prev?.isEnabled != state.isEnabled {
            searchBar.isUserInteractionEnabled = state.isEnabled
        }
    }

    /// 拆卸：失效并置空防抖 Timer、断开 searchBar 代理并清空回调，避免拆桥后仍收到代理回调（见文件头 ⚠️）。
    public func teardown() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        pendingText = nil
        searchBar.delegate = nil
        onIntent = nil
    }

    // MARK: - 防抖（长寿命异步对象，私有弱代理）

    /// 防抖到点 / 提交 / 关防抖时统一走这里收拢文本（去重后上报）。
    fileprivate func flushDebouncedText() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        guard let pending = pendingText else { return }
        pendingText = nil
        reportText(pending)
    }

    private func reportText(_ text: String) {
        guard lastReportedText != text else { return }
        lastReportedText = text
        onIntent?(.textChanged(text))
    }

    // MARK: - UISearchBarDelegate（公开类 → 方法 public；teardown 断 delegate）

    /// 文本变化代理：防抖开启时重排一次性 Timer、到点 flush 最终文本；否则立即按值去重上报。
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard let interval = cached?.debounceInterval, interval > 0 else {
            reportText(searchText)
            return
        }
        // 防抖：重排一次性 Timer，到点 flush 最终文本
        debounceTimer?.invalidate()
        pendingText = searchText
        let timer = Timer(timeInterval: interval,
                          target: WeakTimerProxy(self),
                          selector: #selector(WeakTimerProxy.fire),
                          userInfo: nil,
                          repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        debounceTimer = timer
    }

    /// 键盘「搜索」键：先 flush 防抖收拢待发文本，再上行 submitted，最后收起键盘。
    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        flushDebouncedText()
        onIntent?(.submitted)
        searchBar.resignFirstResponder()
    }

    /// 取消钮：作废挂起的防抖、上行 cancelTapped，并收起键盘。
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        debounceTimer?.invalidate()
        debounceTimer = nil
        pendingText = nil
        onIntent?(.cancelTapped)
        searchBar.resignFirstResponder()
    }
}

// MARK: - Timer 的弱代理

/// Timer 强持有 target：用 NSObject 代理只持 weak owner，避免 SearchFieldBridgeView ↔ Timer
/// 相互保活。回调经 assumeIsolated 落回主演员（与 Carousel/Notice 同款写法）。
/// 拆桥路径：teardown 里先 debounceTimer.invalidate() + 置 nil，否则空转回调。
private final class WeakTimerProxy: NSObject {
    private weak var owner: SearchFieldBridgeView?

    init(_ owner: SearchFieldBridgeView) {
        self.owner = owner
    }

    @objc func fire() {
        guard let owner else { return }
        MainActor.assumeIsolated {
            owner.flushDebouncedText()
        }
    }
}