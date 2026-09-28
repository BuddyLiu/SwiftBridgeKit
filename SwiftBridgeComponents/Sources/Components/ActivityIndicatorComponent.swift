//
//  ActivityIndicatorComponent.swift
//  SwiftBridgeComponents
//
//  加载指示器 —— 展示组件：UIActivityIndicatorView 包装，纯展示无意图。
//
//  教学点：
//    **hidesWhenStopped 的占位语义**：不转就隐藏，但视图本身仍占 SwiftUI 行高
//    （intrinsic 高度不塌缩），切换起停时行不会「跳」。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    isAnimating      → startAnimating() / stopAnimating()
//    size             → style（medium / large，切换时重建转圈形态）
//    tone             → color（转圈颜色）
//    hidesWhenStopped → 停止时是否占位隐藏
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 加载指示器的展示状态：起停 + 尺寸 + 配色 + 停止占位。
public struct ActivityIndicatorState: BridgeState {
    /// 是否转动。
    public var isAnimating: Bool
    /// 尺寸（medium / large）。
    public var size: ActivityIndicatorSize
    /// 配色主题：转圈颜色。
    public var tone: ComponentTone
    /// 停止时是否自动隐藏（默认 true：不转就消失，只占位不显示）。
    public var hidesWhenStopped: Bool

    /// 构造加载指示器状态。
    /// - Parameters:
    ///   - isAnimating: 是否转动；默认 false。
    ///   - size: 尺寸；默认 .medium。
    ///   - tone: 配色主题；默认 .primary。
    ///   - hidesWhenStopped: 停止时是否隐藏；默认 true。
    public init(isAnimating: Bool = false,
                size: ActivityIndicatorSize = .medium,
                tone: ComponentTone = .primary,
                hidesWhenStopped: Bool = true) {
        self.isAnimating = isAnimating
        self.size = size
        self.tone = tone
        self.hidesWhenStopped = hidesWhenStopped
    }
}

// MARK: - 桥视图

/// 加载指示器桥视图：包装 `UIActivityIndicatorView`，纯展示（`NoIntent`）。
@MainActor
public final class ActivityIndicatorBridgeView: UIView, BridgeView {

    /// 桥状态类型：起停 / 尺寸 / 配色。
    public typealias State = ActivityIndicatorState
    /// 桥意图类型：纯展示，用 `NoIntent`。
    public typealias Intent = NoIntent

    /// 意图上抛回调：本组件不产生意图，占位以满足协议。
    public var onIntent: ((NoIntent) -> Void)?

    /// internal（非 private）：留给 @testable 冒烟测试校验起停 / 尺寸路径用。
    let spinner: UIActivityIndicatorView
    private var cached: ActivityIndicatorState?

    /// 构造组件：搭好转圈本体（默认 medium、主色、停止隐藏）与居中约束。
    /// - Parameters:
    ///   - frame: 初始 frame。
    override public init(frame: CGRect) {
        spinner = UIActivityIndicatorView(style: .medium)
        super.init(frame: frame)

        spinner.chain()
            .hidesWhenStopped(true)
            .color(ComponentPalette.color(for: .primary))
            .added(to: self)

        spinner.snp.makeConstraints { make in
            make.centerX.equalTo(self)
            make.centerY.equalTo(self)
        }
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：跟随转圈尺寸；停止占位时至少留 24pt 高，行不塌缩。
    override public var intrinsicContentSize: CGSize {
        let size = spinner.intrinsicContentSize
        return CGSize(width: max(size.width, 24), height: max(size.height, 24))
    }

    // MARK: - BridgeView

    /// 应用最新状态：差分切换起停 / 尺寸 / 配色 / 停止占位。
    /// - Parameters:
    ///   - state: 最新的加载指示器状态。
    public func apply(_ state: ActivityIndicatorState) {
        let prev = cached
        cached = state

        if prev?.isAnimating != state.isAnimating {
            if state.isAnimating {
                spinner.startAnimating()
            } else {
                spinner.stopAnimating()
            }
        }
        if prev?.size != state.size {
            spinner.style = state.size.uiStyle
        }
        if prev?.tone != state.tone {
            spinner.color = ComponentPalette.color(for: state.tone)
        }
        if prev?.hidesWhenStopped != state.hidesWhenStopped {
            spinner.hidesWhenStopped = state.hidesWhenStopped
        }
    }

    /// 拆桥：停转并清掉意图回调。
    public func teardown() {
        spinner.stopAnimating()
        onIntent = nil
    }
}