# SwiftBridgeComponents

SwiftUI 宿主里「现成的 UIKit 桥接组件」：一体打包 SwiftBridgeKit 的桥接契约与
SwiftChainKit 的链式配置，每个组件 = **纯值契约层 + 桥视图 + 差异映射**。

> 定位一句话：**分层复用，不开新写法**。业务侧面向纯值 `State`/`Intent`，
> 视图侧沿用同一套 `apply(差分) / onIntent(上报) / teardown(收口)` 纪律，
> 组件库只是把这条纪律做成了 32 个开箱即用的剖面。

## 组件总表（32 个）

| 分类 | 组件 | 一句话 |
|---|---|---|
| 展示 | Avatar · Badge · Notice · EmptyState · Toast · ActivityIndicator · **StepIndicator** · **Sparkline** | 头像徽章、通知回复、步骤条、迷你趋势图，纯展示为主 |
| 表单 | TextField · TextView · SearchField · Stepper · Slider · DatePicker · **OTPField** · **PickerWheel** | 输入 / 步进 / 日期 / 验证码 / 滚轮，含输入保护 |
| 选择 | Switch · Segmented · Chip · Rating · **Checkbox** · **RadioGroup** | 单项/多项选择，选中态由业务回写 |
| 容器 | List · Grid · Carousel · **PageControl** · **IndexBar** | 复用池 + diffable 增量动画 + 无限轮播 + 分页指标 |
| 按钮 | Button | 五式三号，含加载态 |
| 进度 | ProgressBar | 确定 / 不确定两种 |
| 弹层 | **Dialog** · **ActionSheet** · **BottomSheet** | 弹层容器三件套：动作确认 / 底部动作表 / 连续选择 |

（分批共新增 15 个：第一批 Stepper / DatePicker / TextView / ActivityIndicator，
第二批 OTPField / PickerWheel / PageControl / IndexBar，第三批 Dialog / ActionSheet /
BottomSheet，第四批 Checkbox / RadioGroup / StepIndicator / Sparkline。
SwiftBridgeComponents 依赖 SwiftBridgeKit 与 SwiftChainKit 两个本地包。）

## 设计约定

每个组件都由三层组成，边界不可互渗：

1. **契约层（纯值，public）**：`struct XState: BridgeState` + `enum XIntent: BridgeIntent`。
   所有字段是 `String` / `Double` / 外观枚举 / `Bool`，**不碰 UIKit**（唯一例外：
   Avatar 的 `UIImage` 出于身份一致性需要保留，代价是等值按「同一实例」判）。
2. **桥视图（`@MainActor final class XBridgeView: UIView, BridgeView`）**：`init` 里用
   SwiftChainKit 点语法 + SnapKit 搭约束；`apply(_ state:)` 里 `let prev = cached`
   逐字段差分 —— **已变才动，绝不全量重建**。
3. **意图上报**：点按 / 输入 / 滑动只 `onIntent?(...)` 上抛，业务决定要不要回写
   state；回写后值没变 `BridgeCoordinator` 早退，链路自收敛。
4. **收口**：`teardown()` 幂等 —— 摘 delegate / removeTarget / 停 Timer，不靠
   `dismantleUIView`。Timer 一律私有 `WeakTimerProxy` 持有，不闭包强引用。

外观不做魔法：所有可配外观（色调 / 形态 / 尺寸）都是 ComponentAppearance.swift 里的
**纯值枚举**，视图在 `apply` 时才翻译成 UIColor / UIFont / 圆角。

## 三项纵向设施

分别在主题、无障碍、弹层上横切全部组件，业务按需启用，不阻塞既有用法：

1. **主题可注入** —— 全局 `ComponentTheme.current`（启动注入）+ BridgeHost 每桥 `theme:` 覆盖（运行时换肤）。phase 1 只做颜色：`DynamicColor` 亮/暗双档，暗黑随 trait 自动切换；现有 `ComponentPalette.*` 静态壳默认读全局，零改动获得收益。
2. **无障碍全量** —— 全部组件默认自带关键信息（库内派生 label / 容器单元素化 / 原生控件本身可读），业务可注入覆盖：BridgeHost 新增 `accessibilityLabel/Hint/Value`，非 nil 才写、apply 之后覆盖，业务胜出。
3. **弹层容器** —— `OverlayManager` 窗口注入式 presenter（不走 `present(_:)`，与 SwiftUI sheet / navigation 零冲突），单弹层 LIFO 替换；配套 `Dialog` / `ActionSheet` / `BottomSheet` 三个组件和 SwiftUI 门面 `overlayPresent(isPresented:state:makeView:options:onIntent:onDismiss:)`。

## 接入最小用法

只用 SwiftUI 的 `BridgeHost` + 契约，看不到任何 UIKit 类型：

```swift
import SwiftUI
import SwiftBridgeComponents

struct SomeForm: View {
    @State private var quantity: Double = 3

    var body: some View {
        BridgeHost(
            state: StepperState(value: quantity, min: 0, max: 10, step: 1),
            makeView: { StepperBridgeView() },
            onIntent: { intent in
                if case .changed(let v) = intent { quantity = v }  // 业务管回写
            }
        )
    }
}
```

`SwiftUI.Picker(selection:...)` 的选项想用组件枚举？`ComponentTone.allCases` 这类
`CaseIterable` 直接 `ForEach` 即可。

## 测试与验证

三个包都 `imports UIKit`，**`swift build` 在 macOS 宿主上报 `no such module 'UIKit'`（预期）**。
验证走 iOS 模拟器：

```bash
# 本包全量单测（110 例）
cd SwiftBridgeComponents
xcodebuild test -scheme SwiftBridgeComponents \
  -destination 'platform=iOS Simulator,id=4B3F3F33-104D-4848-B328-449080F36DFE'
```

- `SWIFT_STRICT_CONCURRENCY=complete` 构建零告警（仅为保持与兄弟包的承诺）；
- Demo 工程五页分别对应：**07 基础组件** / **08 容器与导航**（List/Grid/Carousel + PageControl/IndexBar）/
  **09 扩展组件**（Progress/Search/Toast）/ **10 三项设施**（主题 / 无障碍 / 弹层）/
  **11 选择与指标**（Checkbox / RadioGroup / StepIndicator / Sparkline），批量新增组件已同步进 07 与 08；
- 契约层钳制逻辑（Rating 越界、DatePicker 倒计时取 60 的倍数、ProgressBar [0,1]、
  OTPField 格数 4…8、PickerWheel 选中行逐列钳制、IndexBar 热区换算、StepIndicator
  currentIndex 收进 0…count-1…）均有纯函数单测，越界值进不到 UIKit；
- 交互语义验收（Checkbox 点按 / RadioGroup 换选）走 internal fire-* 测试钩子直连
  手势逻辑 —— 无头模拟器不派发 UIControl target-action（见 Overlay 组件同款约定）。

## 相关

- [SwiftBridgeKit](../SwiftBridgeKit/README.md) —— 桥接核心四件设施（BridgeHost / BridgeView / BridgeGuard / SizedBridge）
- [SwiftChainKit](../SwiftChainKit/README.md) —— 点语法配置 DSL，本库的视图搭建工具