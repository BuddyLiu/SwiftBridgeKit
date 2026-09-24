//
//  BridgeGuard.swift
//  SwiftBridgeKit
//
//  设施二：更新抑制器。
//
//  它根治的是这条循环：
//
//      updateUIView → 视图内部回调 → 改 SwiftUI @State → 触发重渲染 → 又 updateUIView → …
//
//  两个实现要点，漏掉任何一个都会变成"修好了卡顿但交互失灵"的事故：
//
//    1. updateDepth 复位必须用 defer。
//       若中途 return / throw 导致标志没复位，抑制器会永久静默，用户操作全部丢失。
//       （深度计数：内层嵌套结束时 defer 先行复位，外层仍保持抑制。）
//
//    2. 上报要延后一拍（DispatchQueue.main.async）。
//       因为 view update 期间修改 SwiftUI state 会触发
//       "Modifying state during view update" 警告，并可能引发未定义行为。
//
//  注意：抑制的是「上报通道」，不是「视图更新」。
//  该刷新视图还是要刷新，只是不要在刷新过程中反向改数据源。
//

import Foundation

/// 更新抑制器：打破「视图更新 → 视图内部回调 → 改 SwiftUI state → 重渲染 → 又更新」的循环。
///
/// 用嵌套深度计数标记「正在把 state 应用到视图」的窗口：窗口内的一切上报直接丢弃，
/// 窗口外的上报延后一拍再投递，避免在视图更新期间反向修改数据源。
@MainActor
public final class BridgeGuard {

    /// 当前「正在把 state 应用到视图」的嵌套深度。
    ///
    /// 用计数而非布尔值：performUpdate 允许嵌套，
    /// 布尔标志会在内层结束（内层 defer 复位）后把外层抑制窗口提前关掉，
    /// 导致外层窗口内本应被抑制的上报漏出，重新接通循环更新路径。
    private var updateDepth = 0

    /// 创建一个更新抑制器。
    public init() {}

    // MARK: - 标记一次视图更新

    /// 把一次「state → view」的写入包起来。
    /// 在这段闭包执行期间发生的任何上报，都会被抑制。
    /// 支持嵌套：只要还有任何一层 performUpdate 未退出，抑制就保持生效。
    public func performUpdate(_ work: () -> Void) {
        updateDepth += 1
        defer { updateDepth -= 1 }     // ⚠️ 必须 defer，不能手动在末尾复位
        work()
    }

    // MARK: - 上报

    /// 从 UIKit 视图向上报一次意图。
    ///
    /// - 若当前正在 performUpdate 中（任意深度）：直接丢弃（打破循环）。
    /// - 否则：延后一拍到下一个 runloop，避免在 view update 期间改 state。
    ///
    /// emit 参数标注为主演员隔离：
    /// 闭包字面量在参数位置会被自动推断为 @MainActor，捕获主线程对象也安全，
    /// 从而消除「把 non-Sendable 闭包交给 DispatchQueue.main.async」的 Swift 6 告警。
    public func emit(_ emit: @escaping @MainActor () -> Void) {
        guard updateDepth == 0 else { return }
        DispatchQueue.main.async { @MainActor in
            emit()
        }
    }

    // MARK: - 免抑制上报（极少数场景）

    /// 明确需要「即使正在更新也要上报」的场景（例如 time out 这类与视图更新无关的事件）。
    /// 使用前请先问：这真的不是循环路径吗？
    public func emitForced(_ emit: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async { @MainActor in
            emit()
        }
    }

    /// 供单测与调试窥探状态。
    public var updating: Bool { updateDepth > 0 }
}
