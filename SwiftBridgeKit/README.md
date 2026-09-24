# SwiftBridgeKit

SwiftUI ↔ UIKit 桥接层的通用适配设施。

**定位一句话：职责薄、能力厚、数量少。**

- **职责薄**：这一层只做适配，不承载业务状态、不做全局布局决策、不被业务反向依赖。
- **能力厚**：尺寸自适应、布局回流、生命周期对齐、状态同步、更新抑制，全部内置做扎实。
- **数量少**：有 SwiftUI 等价物就不要造桥。本包是"少而好"的桥的基础设施，不是"多而杂"的组件库。

> ⚠️ 本包只面向 iOS（imports UIKit），**无法用 macOS 宿主的 `swift build` 直接编译**，
> 验证请走 `scripts/verify.sh`（模拟器编译 + 单测）或在 `SwiftBridgeKitDemo.xcodeproj` 里 Build。
> Swift 6 并发标注（`@MainActor` 隔离）、`sizeThatFits` 的可用性版本，请以你本机 Xcode 与官方文档实测为准。

---

## 目录结构

```
SwiftBridgeKit/
├── Package.swift                     SPM 包定义
├── README.md                         本文件
├── Sources/
│   ├── IntentChannel.swift           契约层：State / Intent 协议（零 UIKit）
│   ├── BridgeGuard.swift             更新抑制器：defer 复位 + 上报延后一拍
│   ├── BridgeView.swift              桥视图协议：apply / onIntent / teardown
│   ├── BridgeCoordinator.swift       通用 Coordinator：早退 + 抑制 + 生命周期收拢
│   ├── BridgeRepresentable.swift     Representable 模板（框架级）
│   ├── SizedBridge.swift             尺寸自适应：ratio 异步就绪 + 布局回流
│   └── LifecyclePolicy.swift         生命周期对齐策略 + 反模式注释
├── Tests/
│   ├── BridgeGuardTests.swift          抑制器单测（含嵌套窗口回归保护）
│   ├── BridgeCoordinatorTests.swift    早退 / 抑制 / attach 集成单测
│   ├── LifecycleTests.swift            OneShotTeardown 幂等单测
│   └── RatioResolverTests.swift        异步比例协调器单测
├── scripts/
│   └── verify.sh                       模拟器编译 + 全量单测（可 CI 复用）
└── Docs/
    └── 08_接入检查表.md              组件接入八步法 Checklist
```

---

## 四件通用设施

| # | 设施 | 文件 | 解决的问题 |
|---|---|---|---|
| 一 | **契约层** | `IntentChannel.swift` | 数据单向流入、意图单向上报，业务侧零 UIKit 依赖 |
| 二 | **更新抑制** | `BridgeGuard.swift` | `updateUIView` 里改 state 导致的循环更新 |
| 三 | **尺寸自适应** | `SizedBridge.swift` | UIKit 视图无法参与 SwiftUI 布局、异步尺寸塌陷 |
| 四 | **生命周期对齐** | `BridgeCoordinator.swift` / `LifecyclePolicy.swift` | `dismantleUIView` 不保证调用、寄存器泄漏 |

---

## 组件接入的最小用法

组件作者只需要写**差异级**的三件事：

```swift
import SwiftBridgeKit
import UIKit

// 1. 定义契约（State 单向流入，Intent 单向上报）
struct PlayerState: BridgeState {
    var url: URL?
    var isPlaying: Bool
}

enum PlayerIntent: BridgeIntent {
    case play, pause, seek(Double)
}

// 2. 定义 UIKit 视图
final class PlayerUIView: UIView, BridgeView {
    var onIntent: ((PlayerIntent) -> Void)?
    func apply(_ state: PlayerState) { /* 差异映射，不要全量重建 */ }
    func teardown() { /* 停播放、断 layer */ }
}

// 3. 声明式外壳（业务只依赖它）
struct LINKVideoPlayer: View {
    let state: PlayerState
    let onIntent: (PlayerIntent) -> Void

    var body: some View {
        BridgeHost(state: state) { PlayerUIView() } onIntent: { onIntent($0) }
    }
}
```

业务侧 `import SwiftBridgeKit` 后**只看得到 `BridgeHost` 和 Intent**，
看不到 `PlayerUIView`、`BridgeCoordinator` 任何类型 —— 换实现零改动。

**尺寸回流（可选）**：若比例是异步才就绪（网络/解码），组件声明
`var onRequestLayout: (() -> Void)?` 并在拿到比例后调用 `onRequestLayout?()`，
框架会请求 SwiftUI 重新布局（见 Demo 02）。纯展示型组件无需写这一行。

---

## 抽模板的时机（重要）

**先有 2 座真实且合格的桥，再抽模板。**

反顺序（先抽模板再套用）的后果：模板带想象痕迹 + 过度设计 + 兼容层自己成了新的技术债。
详见 `Docs/08_接入检查表.md` 第 7 节。

---

## 验证

本包只面向 iOS，`swift build` 在 macOS 宿主会报 `no such module 'UIKit'`（预期）。用模拟器验证：

```bash
# 自动选一台可用 iPhone 模拟器：编译 + 跑全部单测
./scripts/verify.sh

# 或显式指定模拟器
SIM_ID=<设备UUID> ./scripts/verify.sh

# Demo 应用：SwiftBridgeKitDemo.xcodeproj 直接 Build 到模拟器即可
```

单测覆盖（`Tests/` 下）：

| 设施 | 验证点 |
|---|---|
| BridgeGuard | 更新期间上报被抑制 / 结束后放行 / 标志复位 / **嵌套窗口不互相破坏** |
| BridgeCoordinator | 值比较早退 / 状态变化才写视图 / apply 期间上报抑制 / attach 注入 |
| OneShotTeardown | 清理只执行一次、幂等 |
| RatioResolver | 相同比例早退 / 非法值过滤 / reset 清回调 |

若报并发标注（`@MainActor`）错误，请按你本机 Xcode 版本调整
`Package.swift` 的 `platforms` 与各文件的标注。

---

## 相关文档

- `~/LINK-Workspace/桥接层研究/` —— 三层次研究档案（`01` 做正确 / `02` 做标准化 / `03` 可被替代）
- `~/LINK-Workspace/桥接层研究/05_通用适配层设计要点.md` —— 本包的设计依据
