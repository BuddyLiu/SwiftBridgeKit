//
//  SizedBridge.swift
//  SwiftBridgeKit
//
//  设施三：尺寸自适应（异步比例部分）。
//
//  最难的不是「算高度」，而是「比例是异步拿到的」：
//
//      视图已上屏 → 网络/解码完成 → 才知道真实宽高比
//      → 需要主动请求一次重新布局 → 布局会再触发 update → 必须防止循环
//
//  所以这里提供了 RatioResolver：值比较 + 只在上屏后请求一次布局。
//

import UIKit
import SwiftUI   // ProposedViewSize 属于 SwiftUI，缺这个 import 会报 "Cannot find type 'ProposedViewSize' in scope"

/// 提供内容宽高比的桥视图协议。
///
/// contentRatio 为 nil 表示比例未知；就绪后可配合 RatioResolver 触发一次重新布局。
@MainActor
public protocol RatioAwareBridge: AnyObject {
    /// 内容宽高比（宽 / 高）。nil 表示未知。
    var contentRatio: CGFloat? { get set }
}

/// 异步比例就绪的协调器。
///
/// 组件在拿到比例时调用 `resolve(_:)` 即可，它负责：
///  1. 与上次值比较，避免「上报 → 布局 → 再上报」的循环；
///  2. 延后一拍请求 SwiftUI 重新布局。
@MainActor
public final class RatioResolver {

    /// 当前解析出的有效宽高比；nil 表示未知。
    public private(set) var ratio: CGFloat?

    /// 由外层注入：请求 SwiftUI 重新执行一次布局。
    public var onRequestLayout: (() -> Void)?

    /// 创建一个比例解析器。
    public init() {}

    /// 组件拿到（或更新）比例时调用这里。
    public func resolve(_ newRatio: CGFloat?) {
        // 非法值直接忽略，保留上一次有效值
        guard let newRatio, newRatio.isFinite, newRatio > 0 else { return }

        // 关键：与上一次值比较。少了这一步，就会退化成循环更新路径 C。
        guard ratio != newRatio else { return }
        ratio = newRatio

        // 延后一拍：避免在 view update 期间触发布局
        DispatchQueue.main.async { [weak self] in
            self?.onRequestLayout?()
        }
    }

    /// 视图被清理时调用，避免残留回调。
    public func reset() {
        ratio = nil
        onRequestLayout = nil
    }
}

// MARK: - proposal 翻译工具

/// 把 SwiftUI 的 ProposedViewSize 翻译成可参与计算的数值的工具。
public enum ProposedSizeTranslator {

    /// 把 SwiftUI 的 proposal 翻译成一个可用的宽度。
    ///
    /// proposal 的每一维都可能是 nil（表示「不约束 / 交给内容决定」）
    /// 或 .infinity（表示「尽可能大」），直接参与除法会得到 0 或 NaN。
    @available(iOS 16.0, *)
    public static func resolveWidth(
        _ proposal: ProposedViewSize,
        fallback: CGFloat
    ) -> CGFloat? {
        let proposed = proposal.width ?? fallback
        guard proposed.isFinite, proposed > 0 else { return nil }
        return proposed
    }
}
