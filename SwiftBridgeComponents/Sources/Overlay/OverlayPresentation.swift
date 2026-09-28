//
//  OverlayPresentation.swift
//  SwiftBridgeComponents
//
//  弹层设施的「展示参数 + 关闭通道」契约层（设施：弹层容器）。
//
//  纯值层只有两件东西：
//    · OverlayPlacement / OverlayPresentation —— 出现位置与展示配置（全字段默认，
//      业务只需覆写关心的几项；测试传 animationDuration = 0 让动画即时到达终态）；
//    · OverlayDismissChannel —— 三种弹层组件共用的「请求关闭」通道：组件内的动作
//      按钮在需要收起弹层时调用它，由宿主（OverlayGateway 或业务直接接线）决定如何关。
//

import UIKit
import SwiftBridgeKit

// MARK: - 展示参数（纯值）

/// 弹层出现位置：居中卡片或底部上浮。
public enum OverlayPlacement: Hashable, Sendable {
    case center
    case bottom
}

/// 弹层的展示与关闭配置（值类型，全字段有默认；可进 Binding / @State）。
public struct OverlayPresentation: Equatable, Sendable {

    /// 出现位置。
    public var placement: OverlayPlacement
    /// 蒙层黑色 alpha。
    public var dimAlpha: CGFloat
    /// 点按蒙层是否关闭。
    public var dismissOnTapDim: Bool
    /// 卡片拖拽关闭开关（仅 bottom 生效，center 忽略）。
    public var dragToDismiss: Bool
    /// 进出场动画时长（秒）；测试传 0 以便即时到达终态。
    public var animationDuration: TimeInterval

    public init(
        placement: OverlayPlacement = .center,
        dimAlpha: CGFloat = 0.42,
        dismissOnTapDim: Bool = true,
        dragToDismiss: Bool = true,
        animationDuration: TimeInterval = 0.24
    ) {
        self.placement = placement
        self.dimAlpha = dimAlpha
        self.dismissOnTapDim = dismissOnTapDim
        self.dragToDismiss = dragToDismiss
        self.animationDuration = animationDuration
    }
}

// MARK: - 弹层组件共用通道

/// 弹层桥视图共用的「请求关闭」通道。
///
/// Dialog / ActionSheet / BottomSheet 三种组件都遵守它：动作按钮在
/// 「需要业务侧收起弹层」时调用 `onRequestDismiss?()`，宿主负责关容器。
/// 纯展示、不参与弹层的组件不需要碰它。
@MainActor
public protocol OverlayDismissChannel: BridgeView {
    var onRequestDismiss: (() -> Void)? { get set }
}