//
//  Chain+UIDatePicker.swift
//  SwiftChainKit
//
//  日期选择：模式/值/时区/日历/上下限/分钟间隔，以及 iOS 14 的样式偏好（样式偏好在
//   iOS 14 之后是系统层面的全局建议，iOS 17 起由系统统一接管，链上仍透传）。

import UIKit

/// 日期选择器链式设置：模式/值/时区/日历/上下限/分钟间隔，以及 iOS 14 的样式偏好。
///
/// 样式偏好（`preferredDatePickerStyle`）在 iOS 14 之后是系统层面的全局建议，
/// iOS 17 起由系统统一接管显示样式，链上仍原样透传。
public extension Chain where Base: UIDatePicker {

    /// 设置当前选中的日期。
    /// - Parameter date: 新日期。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func date(_ date: Date) -> Chain<Base> {
        base.date = date
        return self
    }

    /// 设置显示模式。
    /// 可选项：`.time` / `.date` / `.dateAndTime` / `.countDownTimer`。
    /// 注意 `.countDownTimer` 模式下只展示时分倒计时，日期相关设置不生效。
    /// - Parameter mode: 显示模式。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func datePickerMode(_ mode: UIDatePicker.Mode) -> Chain<Base> {
        base.datePickerMode = mode
        return self
    }

    /// 设置显示的语言与地区。
    /// - Parameter locale: 语言环境（如 `Locale(identifier: "zh_CN")`）；`nil` 使用系统默认。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func locale(_ locale: Locale?) -> Chain<Base> {
        base.locale = locale
        return self
    }

    /// 设置使用的日历（如公历/农历）。
    /// - Parameter calendar: 日历。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func calendar(_ calendar: Calendar) -> Chain<Base> {
        base.calendar = calendar
        return self
    }

    /// 设置时区。
    /// - Parameter timeZone: 时区（如 `TimeZone(identifier: "Asia/Shanghai")`）；`nil` 使用系统默认。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func timeZone(_ timeZone: TimeZone?) -> Chain<Base> {
        base.timeZone = timeZone
        return self
    }

    /// 设置允许选择的最早日期。
    /// - Parameter date: 最早日期；`nil` 表示不设下限。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func minimumDate(_ date: Date?) -> Chain<Base> {
        base.minimumDate = date
        return self
    }

    /// 设置允许选择的最晚日期。
    /// - Parameter date: 最晚日期；`nil` 表示不设上限。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func maximumDate(_ date: Date?) -> Chain<Base> {
        base.maximumDate = date
        return self
    }

    /// 设置分钟步进间隔（`interval >= 1`）。
    /// 仅 `dateAndTime` / `countDownTimer` 模式生效。
    /// - Parameter interval: 分钟间隔。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func minuteInterval(_ interval: Int) -> Chain<Base> {
        base.minuteInterval = interval
        return self
    }

    /// 设置倒计时初始时长（秒），仅 `datePickerMode(.countDownTimer)` 时生效。
    ///
    /// 注意：值必须是 60 的倍数（60/120/180…），否则实际取值会被系统吸附到最近的合法值。
    /// 等价直接给 `UIDatePicker.countDownDuration` 赋值。
    /// - Parameter duration: 倒计时时长。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func countDownDuration(_ duration: TimeInterval) -> Chain<Base> {
        base.countDownDuration = duration
        return self
    }

    /// 外观偏好（iOS 13.4+）：`.automatic` / `.compact` / `.inline` / `.wheels`。
    /// 只是「偏好」：仍受系统与上下文约束，iOS 17 起由系统统一接管显示样式。
    /// - Parameter style: 样式偏好。
    /// - Returns: 返回自身，支持继续链式设置。
    @discardableResult
    @MainActor
    func preferredDatePickerStyle(_ style: UIDatePickerStyle) -> Chain<Base> {
        base.preferredDatePickerStyle = style
        return self
    }
}