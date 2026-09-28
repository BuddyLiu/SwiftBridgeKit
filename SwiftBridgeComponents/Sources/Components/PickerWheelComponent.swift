//
//  PickerWheelComponent.swift
//  SwiftBridgeComponents
//
//  滚轮选择器 —— 表单组件：UIPickerView 多列包装，标题两维数据源。
//
//  教学点：
//    1. **UIPickerView 无 intrinsic 尺寸**：不提供宽/高 intrinsic → 固定轮盘高
//       （216）给宿主，宽度交给行铺满。
//    2. **数据源是两维的**：`numberOfComponents`（列）× `numberOfRowsInComponent`（行），
//       State 用 `[[String]]` 一对一对齐。
//    3. **程序化 selectRow 天然防环**：didSelectRow 只在用户滚轮时触发，apply 里回写
//       selectRow 不反向上报；仍配 lastReported 去重兜底。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    components   → 变了 `reloadAllComponents()` + 重新落位 selectedRows
//    selectedRows → 逐列差异才 selectRow(_:animated: false)（不触发 didSelect）
//    tone         → picker.tintColor
//    isEnabled    → isUserInteractionEnabled
//  didSelectRow 收起各列行号组数组 + lastReported 去重上报 .changed(rows)。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 滚轮选择器的展示状态：多列数据 + 各列选中行 + 配色与可用性。
public struct PickerWheelState: BridgeState {
    /// 各列数据（`components[i][j]` 即第 i 列第 j 行的文案）。
    public var components: [[String]]
    /// 各列选中行号（init 逐列钳进对应行数、数量对齐列数）。
    public var selectedRows: [Int]
    /// 配色主题：轮盘选中文字色。
    public var tone: ComponentTone
    /// 是否可交互。
    public var isEnabled: Bool

    /// 构造滚轮选择器状态。
    /// - Parameters:
    ///   - components: 各列数据；默认两列（颜色 × 尺寸）。
    ///   - selectedRows: 各列选中行；默认 [0, 0]。init 里逐列钳到 [0, 行数-1]。
    ///   - tone: 配色主题；默认 .primary。
    ///   - isEnabled: 是否可交互；默认 true。
    public init(components: [[String]] = [["红", "绿", "蓝"], ["大", "中", "小"]],
                selectedRows: [Int] = [0, 0],
                tone: ComponentTone = .primary,
                isEnabled: Bool = true) {
        self.components = components
        // 选中行与列对齐：缺列补 0、现值钳到列行数内（纯函数，可单测）
        var rows = Array(repeating: 0, count: components.count)
        for (i, column) in components.enumerated() {
            let raw = i < selectedRows.count ? selectedRows[i] : 0
            rows[i] = column.isEmpty ? 0 : min(max(raw, 0), column.count - 1)
        }
        self.selectedRows = rows
        self.tone = tone
        self.isEnabled = isEnabled
    }
}

/// 滚轮选择器交互意图：各列选中行变化。
public enum PickerWheelIntent: BridgeIntent {
    /// 用户滚轮后上报各列选中行号；外部 selectRow 不触发。
    case changed([Int])
}

// MARK: - 桥视图

/// 滚轮选择器桥视图：包装 `UIPickerView`，self 即数据源/代理。
@MainActor
public final class PickerWheelBridgeView: UIView, BridgeView, UIPickerViewDataSource, UIPickerViewDelegate {

    /// 桥状态类型：多列数据 + 选中行等。
    public typealias State = PickerWheelState
    /// 桥意图类型：各列选中行变化。
    public typealias Intent = PickerWheelIntent

    /// 意图上抛回调：各列选中行变化。
    public var onIntent: ((PickerWheelIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）；`resolvedTheme()` = 本属性 ?? 全局 current。
    public var theme: (any BridgeTheme)?

    /// internal（非 private）：留给 @testable 冒烟测试校验 selectRow 落位用。
    let picker = UIPickerView()
    /// 数据源快照：apply 先落库再差分驱动轮盘（didSelect/数据查询都读它）。
    private var snapshot = PickerWheelState()
    /// 上报去重水印：各列行号没变就不上报。
    private var lastReported: [Int]?
    private var cached: PickerWheelState?
    /// 最近一次生效的主题缓存：主题变化时强制颜色字段重绘。
    private var cachedTheme: ComponentTheme?

    /// 构造组件：数据源/代理接自己，铺满宿主。
    /// - Parameters:
    ///   - frame: 初始 frame。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        picker.chain()
            .dataSource(self)
            .delegate(self)
            .added(to: self)

        picker.snp.makeConstraints { make in
            make.top.bottom.equalTo(self)
            make.leading.trailing.equalTo(self)
        }
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：宽不固定（宿主铺满），高固定为轮盘高（UIPickerView 无 intrinsic）。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: ComponentMetrics.pickerWheelHeight())
    }

    // MARK: - BridgeView

    /// 应用最新状态：数据源快照落库，数据/选中行差分驱动轮盘。
    /// - Parameters:
    ///   - state: 最新的滚轮选择器状态。
    public func apply(_ state: PickerWheelState) {
        // 主题解析：每桥 override → 全局 current；主题变化强制颜色字段重绘
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if prev?.components != state.components {
            snapshot = state
            picker.reloadAllComponents()
            // 数据变了旧选中行号可能越界：按新 state 全部重新落位
            placeSelectedRows(state.selectedRows)
        } else if prev?.selectedRows != state.selectedRows {
            snapshot = state
            // 逐列差异才 selectRow（程序化不回抛 didSelectRow → 天然防环）
            placeSelectedRows(state.selectedRows)
        }
        if themeChanged || prev?.tone != state.tone {
            picker.tintColor = resolvedTheme().color(for: state.tone)
        }
        if picker.isUserInteractionEnabled != state.isEnabled {
            picker.isUserInteractionEnabled = state.isEnabled
        }
    }

    /// 拆桥：断开数据源/代理并清掉意图回调。
    public func teardown() {
        picker.dataSource = nil
        picker.delegate = nil
        onIntent = nil
    }

    // MARK: - UIPickerViewDataSource

    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        snapshot.components.count
    }

    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        guard component < snapshot.components.count else { return 0 }
        return snapshot.components[component].count
    }

    // MARK: - UIPickerViewDelegate

    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        guard component < snapshot.components.count,
              row < snapshot.components[component].count else { return nil }
        return snapshot.components[component][row]
    }

    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // 只在用户滚轮时触发；程序化 selectRow 天然防环
        let rows = (0..<pickerView.numberOfComponents).map { pickerView.selectedRow(inComponent: $0) }
        guard lastReported != rows else { return }
        lastReported = rows
        onIntent?(.changed(rows))
    }

    // MARK: - 差异映射

    /// 把各列选中行落位到轮盘；同时同步 lastReported（程序化不触发 didSelect 已防环）。
    private func placeSelectedRows(_ rows: [Int]) {
        for (i, row) in rows.enumerated() where i < picker.numberOfComponents {
            if picker.selectedRow(inComponent: i) != row {
                picker.selectRow(row, inComponent: i, animated: false)
            }
        }
        lastReported = rows
    }
}