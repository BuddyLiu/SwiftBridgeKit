//
//  ComponentTheme.swift
//  SwiftBridgeComponents
//
//  设施：主题可注入（phase 1 只做颜色）。
//
//  三层：
//    · DynamicColor              —— {light; dark} 双档动态色，暗黑随系统 trait 自动切换；
//    · ComponentPaletteConfiguration —— 调色板（值类型配置，全字段默认 = 系统语义色）；
//    · ComponentTheme            —— 主题（值类型）：全局注入 + 每桥覆盖两个入口。
//
//  两个入口的语义（教学点）：
//    · `ComponentTheme.current`   全局启动注入 —— 变更不会自动重绘已挂载视图；
//    · `theme:` 每桥覆盖（BridgeHost 参数）—— 运行时换肤用，Coordinator 重放 apply 让颜色重绘。
//
//  组件内解析：`resolvedTheme()`（= 桥自带 theme ?? 全局 current）。
//  静态壳 ComponentPalette.*（ComponentAppearance.swift）默认读全局，一行不改就有收益。
//

import UIKit
import SwiftBridgeKit

// MARK: - DynamicColor

/// {light; dark} 双档动态色。`uiColor()` 产出 UIKit 动态色：
/// 视图内直接使用时，暗黑随 trait 自动切换，**无需 apply 重跑**。
///
/// Hashable：供 ComponentTheme 参与 BridgeTheme（Hashable）值比较；
/// 不标 Sendable —— 内含 UIColor 非 Sendable，跨线程语义由 @MainActor 上下文兜底。
public struct DynamicColor: Hashable {

    public let light: UIColor
    public let dark: UIColor

    public init(light: UIColor, dark: UIColor) {
        self.light = light
        self.dark = dark
    }

    /// 单档构造：两态都用同一个颜色。
    /// 传系统语义色（如 UISystemColor 的 .systemBlue）时，其自身的暗黑变体会被保留，
    /// 因此默认主题 = 系统语义色即可全面自适应亮暗。
    public init(_ color: UIColor) {
        self.init(light: color, dark: color)
    }

    /// 解析为 UIKit 动态色（暗黑随 trait 自动切换）。
    public func uiColor() -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? self.dark : self.light
        }
    }
}

// MARK: - 按钮一对色（命名 struct，替代 tuple —— tuple 无法参与 synthesized Equatable）

/// 按钮样式的「背景 + 前景」一对色。
public struct ButtonThemeColors: Hashable {

    public var background: DynamicColor
    public var foreground: DynamicColor

    public init(background: DynamicColor, foreground: DynamicColor) {
        self.background = background
        self.foreground = foreground
    }
}

// MARK: - 调色板配置

/// 调色板（值类型配置）。每个字段默认 = 系统语义色（自动适配亮暗）；
/// 定制主题只需覆写想改的几个字段，其余沿用默认。
public struct ComponentPaletteConfiguration: Hashable {

    // 五 tone（color(for:) / softBackground = tone.withAlpha(0.14)）
    public var neutral: DynamicColor
    public var primary: DynamicColor
    public var success: DynamicColor
    public var warning: DynamicColor
    public var danger: DynamicColor

    // 五式按钮（buttonColors(for:)）
    public var buttonPrimary: ButtonThemeColors
    public var buttonSecondary: ButtonThemeColors
    public var buttonOutline: ButtonThemeColors
    public var buttonGhost: ButtonThemeColors
    public var buttonDanger: ButtonThemeColors
    public var buttonOutlineColor: DynamicColor

    // 评分星色（.system = 宿主 tint，不入配置，见 ComponentPalette.starColor）
    public var starGold: DynamicColor
    public var starPurple: DynamicColor
    public var starTeal: DynamicColor
    public var starPink: DynamicColor

    /// 按钮禁用态 alpha。
    public var buttonDisabledAlpha: CGFloat

    public init(
        neutral: DynamicColor = DynamicColor(.systemGray),
        primary: DynamicColor = DynamicColor(.systemBlue),
        success: DynamicColor = DynamicColor(.systemGreen),
        warning: DynamicColor = DynamicColor(.systemOrange),
        danger: DynamicColor = DynamicColor(.systemRed),
        buttonPrimary: ButtonThemeColors = ButtonThemeColors(
            background: DynamicColor(.systemBlue), foreground: DynamicColor(.white)),
        buttonSecondary: ButtonThemeColors = ButtonThemeColors(
            background: DynamicColor(.systemGray5), foreground: DynamicColor(.label)),
        buttonOutline: ButtonThemeColors = ButtonThemeColors(
            background: DynamicColor(.clear), foreground: DynamicColor(.systemBlue)),
        buttonGhost: ButtonThemeColors = ButtonThemeColors(
            background: DynamicColor(.clear), foreground: DynamicColor(.systemBlue)),
        buttonDanger: ButtonThemeColors = ButtonThemeColors(
            background: DynamicColor(.systemRed), foreground: DynamicColor(.white)),
        buttonOutlineColor: DynamicColor = DynamicColor(.systemBlue),
        starGold: DynamicColor = DynamicColor(.systemYellow),
        starPurple: DynamicColor = DynamicColor(.systemPurple),
        starTeal: DynamicColor = DynamicColor(.systemTeal),
        starPink: DynamicColor = DynamicColor(.systemPink),
        buttonDisabledAlpha: CGFloat = 0.5
    ) {
        self.neutral = neutral
        self.primary = primary
        self.success = success
        self.warning = warning
        self.danger = danger
        self.buttonPrimary = buttonPrimary
        self.buttonSecondary = buttonSecondary
        self.buttonOutline = buttonOutline
        self.buttonGhost = buttonGhost
        self.buttonDanger = buttonDanger
        self.buttonOutlineColor = buttonOutlineColor
        self.starGold = starGold
        self.starPurple = starPurple
        self.starTeal = starTeal
        self.starPink = starPink
        self.buttonDisabledAlpha = buttonDisabledAlpha
    }

    // MARK: - 便捷解析

    public func tone(_ t: ComponentTone) -> DynamicColor {
        switch t {
        case .neutral:  return neutral
        case .primary:  return primary
        case .success:  return success
        case .warning:  return warning
        case .danger:   return danger
        }
    }

    public func button(_ style: ButtonStyle) -> ButtonThemeColors {
        switch style {
        case .primary:   return buttonPrimary
        case .secondary: return buttonSecondary
        case .outline:   return buttonOutline
        case .ghost:     return buttonGhost
        case .danger:    return buttonDanger
        }
    }

    /// 非 `.system` 的星色（`.system` 走宿主 tint，见 ComponentTheme.starColor(for:)）。
    public func star(_ t: RatingStarTone) -> DynamicColor {
        switch t {
        case .system: return DynamicColor(.tintColor)
        case .gold:   return starGold
        case .purple: return starPurple
        case .teal:   return starTeal
        case .pink:   return starPink
        }
    }
}

// MARK: - ComponentTheme

/// 主题（值类型）。phase 1 只承载颜色（调色板）；
/// 字体与度量维持静态现状（ComponentTypography / ComponentMetrics），记为未来扩展。
public struct ComponentTheme: BridgeTheme {

    public var palette: ComponentPaletteConfiguration

    public init(palette: ComponentPaletteConfiguration = ComponentPaletteConfiguration()) {
        self.palette = palette
    }

    // MARK: - 入口

    /// 全局注入（启动时设置）。**变更不会自动重绘已挂载视图** ——
    /// 运行时换肤请用 BridgeHost 每桥 `theme:` 覆盖。
    @MainActor
    public static var current: ComponentTheme = .default

    /// 默认主题：系统语义色（自动适配亮暗）。非 Sendable，故与 current 一致标 @MainActor。
    @MainActor
    public static let `default` = ComponentTheme()

    /// 品牌主题预置（Demo10 教学：换掉 primary/danger/star 几处颜色看联动）。
    @MainActor
    public static let brand = ComponentTheme(palette: .brand)

    // MARK: - 解析助手（供静态壳与每桥 override 复用）

    /// 五 tone → 动态色。
    public func color(for tone: ComponentTone) -> UIColor {
        palette.tone(tone).uiColor()
    }

    /// 五 tone → 浅色底（alpha 0.14）。
    public func softBackground(for tone: ComponentTone) -> UIColor {
        color(for: tone).withAlphaComponent(0.14)
    }

    /// 五式按钮 → (背景, 前景)。
    public func buttonColors(for style: ButtonStyle) -> (background: UIColor, foreground: UIColor) {
        let c = palette.button(style)
        return (c.background.uiColor(), c.foreground.uiColor())
    }

    public func buttonOutlineColor() -> UIColor {
        palette.buttonOutlineColor.uiColor()
    }

    public func buttonDisabledAlpha() -> CGFloat {
        palette.buttonDisabledAlpha
    }

    /// 评分星色。`.system` = 宿主强调色（tintColor，动态语义），不入调色板。
    public func starColor(for tone: RatingStarTone) -> UIColor {
        switch tone {
        case .system:                     return .tintColor
        case .gold, .purple, .teal, .pink: return palette.star(tone).uiColor()
        }
    }
}

// MARK: - 品牌主题预置

extension ComponentPaletteConfiguration {

    /// 品牌主题：primary 换紫、danger 换酒红、star 换金（其余沿用系统语义色）。
    public static var brand: ComponentPaletteConfiguration {
        ComponentPaletteConfiguration(
            primary: DynamicColor(
                light: UIColor(red: 0.52, green: 0.36, blue: 0.95, alpha: 1),
                dark: UIColor(red: 0.72, green: 0.58, blue: 1.0, alpha: 1)),
            danger: DynamicColor(
                light: UIColor(red: 0.70, green: 0.18, blue: 0.24, alpha: 1),
                dark: UIColor(red: 0.92, green: 0.40, blue: 0.46, alpha: 1)),
            starGold: DynamicColor(
                light: UIColor(red: 0.96, green: 0.70, blue: 0.20, alpha: 1),
                dark: UIColor(red: 0.98, green: 0.80, blue: 0.34, alpha: 1))
        )
    }
}

// MARK: - 每桥覆盖的解析入口

/// 当前生效主题：每桥 override（view.theme）优先，否则回落全局注入 `ComponentTheme.current`。
/// 该扩展在 @MainActor 的 BridgeView 协议上，apply 内直接调用零并发摩擦。
public extension BridgeView {

    /// 解析当前生效的组件主题。
    func resolvedTheme() -> ComponentTheme {
        (theme as? ComponentTheme) ?? ComponentTheme.current
    }
}