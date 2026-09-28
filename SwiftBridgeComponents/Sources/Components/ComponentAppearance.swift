//
//  ComponentAppearance.swift
//  SwiftBridgeComponents
//
//  共享样式基础设施。
//
//  分层：
//    顶部 —— 纯值外观枚举（public）：零 UIKit，可进 BridgeState 字段与 init 默认值。
//    底部 —— UIKit 映射（internal）：只给本模块的桥视图在 apply 里用。
//
//  这样桥的两侧各自纯粹：业务侧只谈「样式枚举」，UIKit 侧只在 apply 时翻译成颜色/字体/圆角。
//

import UIKit

// MARK: - 纯值外观枚举（Hashable / CaseIterable，可进 State）

// ⚠️ 统一用 Hashable 而非 Equatable：列表/网格/轮播的「值模型数组做集合比较
//    （rows != state.rows → 差分 reload）需要 ==；diffable 需要 Hashable；
//    纯值枚举零成本，两个都免费给到。

/// 通用色调：Badge、占位符、头像边框等共用。
/// Sendable：进 GridCell / ListRow 这类「diffable / 跨线程安全」值模型。
public enum ComponentTone: Hashable, CaseIterable, Sendable {
    case neutral, primary, success, warning, danger
}

/// 按钮样式。与 ButtonSize 分开，便于组合出「小号 outline」这类搭配。
public enum ButtonStyle: Hashable, CaseIterable {
    case primary, secondary, outline, ghost, danger
}

/// 按钮尺寸：决定高度、字体与圆角。
public enum ButtonSize: Hashable, CaseIterable {
    case regular, large, small
}

/// 按钮图标相对文字的位置。
public enum ButtonIconPosition: Hashable, CaseIterable {
    case leading, trailing
}

/// 徽章形态：pill 全圆角胶囊或 round 小圆角。
public enum BadgeShape: Hashable, CaseIterable {
    case pill, round
}

/// 头像形态：circular 圆形或 roundedRect 圆角方形。
public enum AvatarShape: Hashable, CaseIterable {
    case circular, roundedRect
}

/// 键盘类型（纯值，避免让 State 直接拿 UITextView/UITextField 的类型）。
public enum KeyboardKind: Hashable, CaseIterable {
    case standard, email, numberPad, decimalPad, phone, url
}

/// 输入框边框样式：圆角矩形、无边框或下划线。
public enum TextFieldBorder: Hashable, CaseIterable {
    case roundedRect, plain, underline
}

/// 评分星色。`.system` = tintColor，保留 Demo01 的原始行为。
public enum RatingStarTone: Hashable, CaseIterable {
    case system, gold, purple, teal, pink
}

/// 日期选择器模式（纯值，映射到 UIDatePicker.Mode）。
public enum DatePickerKind: Hashable, CaseIterable {
    case date, time, dateAndTime, countDown
}

/// 加载指示器尺寸（纯值，映射到 UIActivityIndicatorView.Style）。
public enum ActivityIndicatorSize: Hashable, CaseIterable {
    case medium, large
}

// MARK: - UIKit 映射（internal，仅本模块视图用）

enum ComponentPalette {

    /// 通用色调 → 主题色。
    static func color(for tone: ComponentTone) -> UIColor {
        switch tone {
        case .neutral:  return .systemGray
        case .primary:  return .systemBlue
        case .success:  return .systemGreen
        case .warning:  return .systemOrange
        case .danger:   return .systemRed
        }
    }

    /// 主题色的浅色底（Badge 底、状态块底）。
    static func softBackground(for tone: ComponentTone) -> UIColor {
        color(for: tone).withAlphaComponent(0.14)
    }

    /// 按钮样式 → (背景色, 前景色)。
    static func buttonColors(for style: ButtonStyle) -> (background: UIColor, foreground: UIColor) {
        switch style {
        case .primary:   return (.systemBlue, .white)
        case .secondary: return (.systemGray5, .label)
        case .outline:   return (.clear, .systemBlue)
        case .ghost:     return (.clear, .systemBlue)
        case .danger:    return (.systemRed, .white)
        }
    }

    /// outline 样式的边框色。
    static func buttonOutlineColor() -> UIColor { .systemBlue }
    static func buttonDisabledAlpha() -> CGFloat { 0.5 }

    /// 评分星色。
    static func starColor(for tone: RatingStarTone) -> UIColor {
        switch tone {
        case .system: return .tintColor
        case .gold:   return .systemYellow
        case .purple: return .systemPurple
        case .teal:   return .systemTeal
        case .pink:   return .systemPink
        }
    }
}

enum ComponentTypography {

    static func buttonFont(for size: ButtonSize) -> UIFont {
        let point: CGFloat = switch size {
        case .small: 13
        case .regular: 15
        case .large: 17
        }
        return .systemFont(ofSize: point, weight: .semibold)
    }

    static func badgeFont() -> UIFont {
        .systemFont(ofSize: 12, weight: .medium)
    }

    static func fieldFont() -> UIFont {
        .systemFont(ofSize: 15)
    }

    /// 验证码格内字符：20 号 semibold。
    static func otpFont() -> UIFont {
        .systemFont(ofSize: 20, weight: .semibold)
    }

    /// 字母索引条字符：10 号 medium。
    static func indexBarFont() -> UIFont {
        .systemFont(ofSize: 10, weight: .medium)
    }

    static func initialsFont(dimension: CGFloat) -> UIFont {
        .systemFont(ofSize: dimension * 0.4, weight: .medium)
    }

    static func chipFont() -> UIFont {
        .systemFont(ofSize: 13, weight: .medium)
    }

    static func noticeTitleFont() -> UIFont {
        .systemFont(ofSize: 14, weight: .semibold)
    }

    static func noticeBodyFont() -> UIFont {
        .systemFont(ofSize: 13)
    }

    static func emptyTitleFont() -> UIFont {
        .systemFont(ofSize: 17, weight: .semibold)
    }

    static func emptyMessageFont() -> UIFont {
        .systemFont(ofSize: 14)
    }

    static func toastFont() -> UIFont {
        .systemFont(ofSize: 15, weight: .medium)
    }

    static func gridTitleFont() -> UIFont {
        .systemFont(ofSize: 12, weight: .medium)
    }

    static func gridBadgeFont() -> UIFont {
        .systemFont(ofSize: 10, weight: .semibold)
    }

    static func carouselTitleFont() -> UIFont {
        .systemFont(ofSize: 18, weight: .bold)
    }

    static func carouselSubtitleFont() -> UIFont {
        .systemFont(ofSize: 13)
    }
}

enum ComponentMetrics {

    static func buttonHeight(for size: ButtonSize) -> CGFloat {
        switch size {
        case .small: 32
        case .regular: 40
        case .large: 48
        }
    }

    static func buttonCornerRadius(for size: ButtonSize) -> CGFloat {
        switch size {
        case .small: 8
        case .regular: 10
        case .large: 12
        }
    }

    static func badgeHeight() -> CGFloat { 22 }

    static func badgeCornerRadius(shape: BadgeShape, height: CGFloat) -> CGFloat {
        shape == .pill ? height / 2 : min(8, height / 2)
    }

    static func avatarCornerRadius(shape: AvatarShape, dimension: CGFloat) -> CGFloat {
        shape == .circular ? dimension / 2 : dimension * 0.28
    }

    /// 头像「在线状态点」：尺寸 / 相对右下角的内缩 / 白色描边环宽。
    static func avatarStatusDotSize() -> CGFloat { 10 }
    static func avatarStatusDotInset() -> CGFloat { 2 }
    static func avatarStatusDotRing() -> CGFloat { 2 }

    static func fieldHeight() -> CGFloat { 48 }

    /// 多行输入框（TextView）高度基线。
    static func textViewHeight() -> CGFloat { 100 }

    // OTPField（验证码格子）
    static func otpBoxSize() -> CGFloat { 44 }
    static func otpBoxSpacing() -> CGFloat { 10 }

    // IndexBar（字母索引条宽）
    static func indexBarWidth() -> CGFloat { 22 }

    // PickerWheel（UIPickerView 无 intrinsic，固定轮盘高）
    static func pickerWheelHeight() -> CGFloat { 216 }

    static func chipHeight() -> CGFloat { 32 }
    static func chipPaddingX() -> CGFloat { 16 }
    static func chipIconSize() -> CGFloat { 16 }
    static func chipIconSpacing() -> CGFloat { 4 }

    static func noticeHeight(showsMessage: Bool) -> CGFloat { showsMessage ? 64 : 40 }

    static func emptyStateHeight() -> CGFloat { 200 }
    static func emptyIconSize() -> CGFloat { 48 }
    static func emptyActionWidth() -> CGFloat { 120 }

    // ProgressBar
    static func progressBarHeight() -> CGFloat { 6 }

    // Toast
    static func toastCardHeight() -> CGFloat { 48 }
    static func toastCornerRadius() -> CGFloat { 12 }
    static func toastBottomOffset() -> CGFloat { 24 }
    static func toastIconSize() -> CGFloat { 20 }

    // List / Grid / Carousel（复杂视图）
    static func listRowHeight() -> CGFloat { 52 }
    static func gridCellCorner() -> CGFloat { 10 }
    static func gridIconSize() -> CGFloat { 26 }
    static func gridBadgeHeight() -> CGFloat { 16 }
    static func carouselBannerHeight() -> CGFloat { 160 }
    static func carouselDotHeight() -> CGFloat { 20 }
}

extension KeyboardKind {
    var uiKeyboardType: UIKeyboardType {
        switch self {
        case .standard:   return .default
        case .email:      return .emailAddress
        case .numberPad:  return .numberPad
        case .decimalPad: return .decimalPad
        case .phone:      return .phonePad
        case .url:        return .URL
        }
    }
}

extension DatePickerKind {
    /// 纯值枚举 → UIDatePicker.Mode（apply 时翻译）。
    var uiMode: UIDatePicker.Mode {
        switch self {
        case .date:        return .date
        case .time:        return .time
        case .dateAndTime: return .dateAndTime
        case .countDown:   return .countDownTimer
        }
    }
}

extension ActivityIndicatorSize {
    /// 纯值枚举 → UIActivityIndicatorView.Style（apply 时翻译）。
    var uiStyle: UIActivityIndicatorView.Style {
        switch self {
        case .medium: return .medium
        case .large:  return .large
        }
    }
}