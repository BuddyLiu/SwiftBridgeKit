//
//  PageControlComponent.swift
//  SwiftBridgeComponents
//
//  分页指示器 —— 容器/导航组件：UIPageControl 包装，当前页圆点高亮。
//
//  教学点：
//    1. **下行 ≠ 上行**：程序化赋值 `currentPage` 不触发 valueChanged（UIKit 事实），
//       所以「外部跳页」是纯下行命令，天然防环；只有用户点圆点才反向上报。
//    2. **单页自动隐藏仍占位**：`hidesForSinglePage` 只是视觉消失，intrinsic 高度不塌缩，
//       页数 1 → 0 时行不会「跳」。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    pageCount   → numberOfPages（页数收敛后当前页随钳，防越界）
//    currentPage → currentPage（差异才写 + 同步 lastReported）
//    tone / currentTone → pageIndicatorTintColor / currentPageIndicatorTintColor
//    hidesForSinglePage / isEnabled → 直写
//  valueChanged 里 lastReported 去重后上报 .pageChanged(currentPage)。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 分页指示器的展示状态：总页数 + 当前页 + 未选/选中双色调 + 单页隐藏 + 可用性。
public struct PageControlState: BridgeState {
    /// 总页数（init 钳 >= 0）。
    public var pageCount: Int
    /// 当前页（init 钳到 [0, pageCount-1]）。
    public var currentPage: Int
    /// 未选中圆点色调。
    public var tone: ComponentTone
    /// 选中圆点色调。
    public var currentTone: ComponentTone
    /// 单页时是否自动隐藏圆点。
    public var hidesForSinglePage: Bool
    /// 是否可交互。
    public var isEnabled: Bool

    /// 构造分页指示器状态。
    /// - Parameters:
    ///   - pageCount: 总页数；默认 0。
    ///   - currentPage: 当前页；默认 0。init 里钳到 [0, pageCount-1]。
    ///   - tone: 未选中圆点色调；默认 .neutral。
    ///   - currentTone: 选中圆点色调；默认 .primary。
    ///   - hidesForSinglePage: 单页自动隐藏；默认 true。
    ///   - isEnabled: 是否可交互；默认 true。
    public init(pageCount: Int = 0,
                currentPage: Int = 0,
                tone: ComponentTone = .neutral,
                currentTone: ComponentTone = .primary,
                hidesForSinglePage: Bool = true,
                isEnabled: Bool = true) {
        let count = max(0, pageCount)
        self.pageCount = count
        // 当前页钳到有效区间；无页时归 0（纯函数，可单测）
        self.currentPage = count == 0 ? 0 : min(max(currentPage, 0), count - 1)
        self.tone = tone
        self.currentTone = currentTone
        self.hidesForSinglePage = hidesForSinglePage
        self.isEnabled = isEnabled
    }
}

/// 分页指示器交互意图：当前页变化（只来自用户点圆点，不来自程序化跳页）。
public enum PageControlIntent: BridgeIntent {
    /// 用户点了某个圆点后上报新页码。
    case pageChanged(Int)
}

// MARK: - 桥视图

/// 分页指示器桥视图：包装 `UIPageControl`，程序化改页不反向上报。
@MainActor
public final class PageControlBridgeView: UIView, BridgeView {

    /// 桥状态类型：总页数 + 当前页等。
    public typealias State = PageControlState
    /// 桥意图类型：页码变化。
    public typealias Intent = PageControlIntent

    /// 意图上抛回调：页码变化。
    public var onIntent: ((PageControlIntent) -> Void)?

    /// internal（非 private）：留给 @testable 冒烟测试校验 apply 写值用。
    let pageControl = UIPageControl()
    /// 上报去重水印：值没变就不上报，防闭环。
    private var lastReported: Int?
    private var cached: PageControlState?

    /// 构造组件：搭好页码圆点、值变化事件与铺满约束。
    /// - Parameters:
    ///   - frame: 初始 frame。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        pageControl.chain()
            .hidesForSinglePage(true)
            .pageIndicatorTintColor(ComponentPalette.color(for: .neutral))
            .currentPageIndicatorTintColor(ComponentPalette.color(for: .primary))
            .target(self, action: #selector(valueChanged), for: .valueChanged)
            .added(to: self)

        pageControl.snp.makeConstraints { make in
            make.top.bottom.equalTo(self)
            make.leading.trailing.equalTo(self)
        }
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：跟随 UIPageControl 本身（宽随页数、高为圆点行高）。
    override public var intrinsicContentSize: CGSize {
        pageControl.intrinsicContentSize
    }

    // MARK: - BridgeView

    /// 应用最新状态：逐字段差分更新页数 / 当前页 / 双色调 / 单页隐藏。
    /// - Parameters:
    ///   - state: 最新的分页指示器状态。
    public func apply(_ state: PageControlState) {
        let prev = cached
        cached = state

        // 页数差异才写；页数收敛后 currentPage 可能越界 → 随钳到 state 的有效值
        if pageControl.numberOfPages != state.pageCount {
            pageControl.numberOfPages = state.pageCount
        }
        if pageControl.currentPage != state.currentPage {
            // 程序化赋值不触发 valueChanged → 天然防环；仍同步 lastReported 兜底
            pageControl.currentPage = state.currentPage
            lastReported = state.currentPage
        }
        if prev?.tone != state.tone {
            pageControl.pageIndicatorTintColor = ComponentPalette.color(for: state.tone)
        }
        if prev?.currentTone != state.currentTone {
            pageControl.currentPageIndicatorTintColor = ComponentPalette.color(for: state.currentTone)
        }
        if pageControl.hidesForSinglePage != state.hidesForSinglePage {
            pageControl.hidesForSinglePage = state.hidesForSinglePage
        }
        if pageControl.isEnabled != state.isEnabled { pageControl.isEnabled = state.isEnabled }
    }

    /// 拆桥：摘除 target 事件并清掉意图回调。
    public func teardown() {
        pageControl.removeTarget(self, action: nil, for: .allEvents)
        onIntent = nil
    }

    // MARK: - 事件（去重上报）

    @objc private func valueChanged() {
        let current = pageControl.currentPage
        guard lastReported != current else { return }
        lastReported = current
        onIntent?(.pageChanged(current))
    }
}