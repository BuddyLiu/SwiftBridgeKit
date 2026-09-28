# SwiftBridgeComponents

SwiftUI 宿主里「现成的 UIKit 桥接组件」：一体打包 SwiftBridgeKit 的桥接契约与
SwiftChainKit 的链式配置，每个组件 = **纯值契约层 + 桥视图 + 差异映射**。

> 定位一句话：**分层复用，不开新写法**。业务侧面向纯值 `State`/`Intent`，
> 视图侧沿用同一套 `apply(差分) / onIntent(上报) / teardown(收口)` 纪律，
> 组件库只是把这条纪律做成了 25 个开箱即用的剖面。

## 组件总表（25 个）

| 分类 | 组件 | 一句话 |
|---|---|---|
| 展示 | Avatar · Badge · Notice · EmptyState · Toast · ActivityIndicator | 头像徽章、通知回复，纯展示为主 |
| 表单 | TextField · TextView · SearchField · Stepper · Slider · DatePicker · **OTPField** · **PickerWheel** | 输入 / 步进 / 日期 / 验证码 / 滚轮，含输入保护 |
| 选择 | Switch · Segmented · Chip · Rating | 单项/多项选择，选中态由业务回写 |
| 容器 | List · Grid · Carousel · **PageControl** · **IndexBar** | 复用池 + diffable 增量动画 + 无限轮播 + 分页指标 |
| 按钮 | Button | 五式三号，含加载态 |
| 进度 | ProgressBar | 确定 / 不确定两种 |

（两次共新增 8 个：第一批 Stepper / DatePicker / TextView / ActivityIndicator，
第二批 OTPField / PickerWheel / PageControl / IndexBar。SwiftBridgeComponents 依赖
SwiftBridgeKit 与 SwiftChainKit 两个本地包。）

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
# 本包全量单测（59 例）
cd SwiftBridgeComponents
xcodebuild test -scheme SwiftBridgeComponents \
  -destination 'platform=iOS Simulator,id=4B3F3F33-104D-4848-B328-449080F36DFE'
```

- `SWIFT_STRICT_CONCURRENCY=complete` 构建零告警（仅为保持与兄弟包的承诺）；
- Demo 工程三页分别对应：**07 基础组件** / **08 容器与导航**（List/Grid/Carousel + PageControl/IndexBar）/
  **09 扩展组件**（Progress/Search/Toast），批量新增组件已同步进 07 与 08；
- 契约层钳制逻辑（Rating 越界、DatePicker 倒计时取 60 的倍数、ProgressBar [0,1]、
  OTPField 格数 4…8、PickerWheel 选中行逐列钳制、IndexBar 热区换算…）均有纯函数单测，
  越界值进不到 UIKit。

## 相关

- [SwiftBridgeKit](../SwiftBridgeKit/README.md) —— 桥接核心四件设施（BridgeHost / BridgeView / BridgeGuard / SizedBridge）
- [SwiftChainKit](../SwiftChainKit/README.md) —— 点语法配置 DSL，本库的视图搭建工具