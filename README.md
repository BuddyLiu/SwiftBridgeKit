# SwiftBridgeKit — SwiftUI ↔ UIKit 桥接实践

一套「SwiftUI 与 UIKit 共处一屏」的完整方案落地：**桥接核心库 + UIKit 链式 DSL + 组件库 + 09 个可运行教学 Demo**，外加离线可用的验证脚本。

> 一句话定位：**职责薄、能力厚、数量少。**
> 有 SwiftUI 等价物就不要造桥；需要桥的地方，把这四件事做扎实 ——
> 状态下行、意图上行、更新抑制、生命周期收口。

---

## 仓库布局

```
SwiftBridgeKit/
├── SwiftBridgeKit/          桥接核心库（SPM，仅 iOS）
│   ├── Sources/…            BridgeView / BridgeCoordinator / BridgeGuard / SizedBridge…
│   └── Docs/08_接入检查表.md  组件接入八步法
├── SwiftChainKit/           点语法链式配置 UIKit 的 DSL（SPM，零依赖，仅 iOS）
├── SwiftBridgeComponents/   SwiftUI 组件库（SPM，25 个组件）
├── SwiftBridgeKitDemo/      Demo 工程（.xcodeproj）—— 09 个可运行教学页
├── Vendor/SnapKit/          SnapKit 本地 vendored（离线也能完整构建）
└── scripts/verify.sh        双包验证脚本：自动挑模拟器 → 编译 + 全量单测
```

## 三个包各做什么

| 包 | 管的事 | 一句话 |
|---|---|---|
| **SwiftBridgeKit** | 桥接契约与运行时 | `State` 单向下行、`Intent` 单向上报、`BridgeGuard` 抑制更新环、`SizedBridge` 异步尺寸回流、`teardown` 生命周期收口 |
| **SwiftChainKit** | UIKit 视图创建 | 把 `titleLabel.text=…; titleLabel.font=…; addSubview…` 的 boilerplate 收成 `.chain().text(_:).font(_:).added(to:).build()`，保型不断 |
| **SwiftBridgeComponents** | 现成组件 | Avatar / Badge / Button / Carousel / Chip / DatePicker / EmptyState / Grid / IndexBar / List / Notice / OTPField / PageControl / PickerWheel / ProgressBar / Rating / SearchField / Segmented / Slider / Stepper / Switch / TextField / TextView / Toast / ActivityIndicator |

分层而不是一个大库：**桥接层**只做适配、不背业务状态；**链式层**只管配置 DSL、不做布局魔法；**组件层**才谈得上「组件」。—— 三层职责互不渗透，各自可独立使用。

## 桥怎么工作

```
SwiftUI 是唯一真相
      │ state 单向下行                 intent 单向上报
      ▼                                 ▲
 ┌──────────┐  apply(差值)   ┌──────────────────────┐
 │ BridgeHost │ ────────────► │ UIKit 视图(apply/onIntent) │
 └──────────┘ ◄────────────  └──────────────────────┘
      │  parseIntent(intent)
      ▼
 SwiftUI @State 更新
```

- **应用侧只用 `BridgeHost` + 契约**，看不到任何 UIKit 类型 —— 换实现零改动；
- 更新路径经 `BridgeGuard` 去环，state 未变时 `BridgeCoordinator` 早退，绝不产生无效写；
- 拆桥时 `teardown` 统一收口 delegate/通知/KVO —— 不靠 `dismantleUIView`（它不保证被调用）。

## Demo 一览（可在模拟器逐页跑）

| # | 页面 | 教学点 |
|---|---|---|
| 01 | 最小闭环（Rating） | state 下行 / intent 上行 / 更新抑制 |
| 02 | 异步比例回流 | 视图上屏后才知道尺寸 → 主动请求 SwiftUI 重新布局 |
| 03 | 表单 TextField / TextView | 双向 text 同步的环 → 输入保护 + 差异回写 |
| 04 | 可滚动容器 ScrollView | offset 上报去重 / 程序化滚动自收敛 / delegate 断连 |
| 05 | 列表 TableView | 复用池 + 内容未变早退 / teardown 断连 |
| 06 | 网格 CollectionView | DiffableDataSource 增量动画 |
| 07–09 | 组件库三页 | SwiftChainKit + SwiftBridgeComponents 的 SwiftUI 用法 |

## 快速开始

```bash
# 1. 打开 Demo 工程，Build 到模拟器
open SwiftBridgeKitDemo/SwiftBridgeKitDemo.xcodeproj

# 2. 命令行直达某页（环境变量 DEMO=NN，1–9）
xcrun simctl boot "iPhone 15" || true
xcrun simctl install booted \
  <DerivedData>/Build/Products/Debug-iphonesimulator/SwiftBridgeKitDemo.app
SIMCTL_CHILD_DEMO=04 xcrun simctl launch booted liu.SwiftBridgeKitDemo

# 3. 跑两包全量单测（自动挑一台能启动的 iPhone 模拟器）
./scripts/verify.sh
```

## 验证须知（仅 iOS）

三个包都 `imports UIKit`，**macOS 宿主上 `swift build` 会报 `no such module 'UIKit'`（预期）**。
验证必须走 iOS 模拟器，两种方式：
- `./scripts/verify.sh` —— 自动挑可用模拟器，编译两包 + 跑全部单测；
- 在 `SwiftBridgeKitDemo.xcodeproj` 里直接 Build。

Demo 工程通过 `XCLocalSwiftPackageReference` 以本地 path 引用三个包与 `Vendor/SnapKit`，
因此**本机离线也能完整构建**；Swift 6 并发标注（`@MainActor` 隔离）请以你本机 Xcode 实测为准。

## 相关文档

- [SwiftBridgeKit/README.md](SwiftBridgeKit/README.md) —— 桥接核心四件设施详解 + 组件接入最小用法
- [SwiftBridgeComponents/README.md](SwiftBridgeComponents/README.md) —— 25 个组件总表 + 分层设计约定 + 接入样例
- [SwiftChainKit/README.md](SwiftChainKit/README.md) —— 链库设计思路（含与 ZZFLEX 的对比）+ 支持类型清单
- [SwiftBridgeKit/Docs/08_接入检查表.md](SwiftBridgeKit/Docs/08_接入检查表.md) —— 接入八步法 Checklist

## License

SwiftChainKit 以 MIT 发布（见 [SwiftChainKit/LICENSE](SwiftChainKit/LICENSE)）；
其余包与 Demo 的授权见作者。