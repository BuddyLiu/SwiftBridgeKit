# SwiftChainKit

点语法链式配置 UIKit 视图的轻量开源库（Zero-Dependency、Swift 泛型、`@MainActor`）。

受 [ZZFLEX](https://github.com/libobjc/ZZFLEX) 的「点语法链式访问」思路启发，但用 Swift
强类型泛型重写，并收敛到「只做配置链 DSL」的边界——不做 flexible 数据驱动布局套件，
不内置任何约束魔法。

## 为什么会有这个库

UIKit 视图的配置总是同一种 boilerplate：

```swift
let titleLabel = UILabel()
titleLabel.text = "你好"
titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
titleLabel.textColor = .systemBlue
titleLabel.textAlignment = .center
parent.addSubview(titleLabel)
titleLabel.translatesAutoresizingMaskIntoConstraints = false
```

用 SwiftChainKit 写成一串可持续的点语法：

```swift
let titleLabel = UILabel().chain()
    .text("你好")
    .font(.systemFont(ofSize: 16, weight: .semibold))
    .textColor(.systemBlue)
    .textAlignment(.center)
    .added(to: parent)
    .autolayout()
    .build()
```

## 相比 ZZFLEX 的改进

| # | ZZFLEX | SwiftChainKit |
|---|--------|---------------|
| 1 | ObjC category，`id` 弱类型，运行时才暴露错误 | Swift 泛型 `Chain<Base>`，`Chain<UILabel>` 只暴露 UILabel 方法，编译期拦错 |
| 2 | 无主线程约束 | 全量 `@MainActor`，strict-concurrency 零告警 |
| 3 | 依赖 MMKV/Masonry 等 | **零依赖**，开箱即用 |
| 4 | 内置布局/数据驱动套件 | 只做配置链；布局交给 SnapKit 或用方自己 |
| 5 | 需要 `end()` 等链终止标记 | `.build()` 即终点，语义自明 |

## 核心设计

- `public struct Chain<Base>` 持有 `base`；`view.chain()`（`UIView` extension，返回
  `Chain<Self>`）进入链，保型不断。
- 每个方法挂在 `extension Chain where Base == X` 上、返回 `Chain<Base>`：
  - 避免了 `var text` 与 `func text(_:)` 无法同名的 Swift 限制（SnapKit 用 `snp`
    命名空间的同一个原因）；
  - `UILabel().chain()` 后面**只跟得到** UILabel 的方法。
- 终端 `.build() -> Base`：取回配置完的本体。
- 逃生口 `.also { (Base) -> Void }`：链中间插入任意副作用（手势、约束、动画…），
  链不断。
- 层级 `.added(to: UIView)` 与 `.autolayout()`：最常用的两个「挂载」动作收进基座。

## 支持的类型与方法

`Chain+UIView.swift`（基座：frame/bounds/center/alpha/isHidden/backgroundColor/tintColor/
contentMode/cornerRadius/border/shadow/layoutMargins/hugging/accessibility…，含手势挂接与
layoutIfNeeded/sizeToFit 等动作方法）、`Chain+UILabel.swift`、`Chain+UIImageView.swift`、
`Chain+UIButton.swift`（含 `UIButton.chain(type:)` 工厂）、`Chain+UIStackView.swift`、
`Chain+UIScrollView.swift`（含滚动条细分内边距）、`Chain+UIViewControls.swift`
（UIControl 基座 / UISwitch / UISegmentedControl / UISlider / UITextField / UISearchBar，
收入 inputView/inputAccessoryView）、`Chain+UITextView.swift`、`Chain+UITableView.swift`、
`Chain+UICollectionView.swift`、`Chain+UIPageControl.swift`、`Chain+UIProgressView.swift`、
`Chain+UIActivityIndicatorView.swift`、`Chain+UIStepper.swift`、`Chain+UIDatePicker.swift`、
`Chain+UIPickerView.swift`、`Chain+UIRefreshControl.swift`、`Chain+UIVisualEffectView.swift`、
`Chain+UIGestureRecognizer.swift`（7 种常用手势 + `.added(to:)` 挂载）、
`Chain+UIBarItem.swift`（UIBarButtonItem / UITabBarItem / UINavigationItem 静态工厂）、
`Chain+UIBars.swift`（UINavigationBar / UITabBar / UIToolbar，含 iOS 13/15 外观组）。

方法集以「iOS 15 上可用的 UIKit 视图属性尽量都支持」为目标：普通属性收敛为同名链方法
（`isHidden(_:)` / `backgroundColor(_:)`…），状态相关 setter 走 `(_:for:)` 形态
（`title(_:for:)`），带动画的收默认参数（`isOn(_:animated: = false)`）、
两段式 API 收成属性式开关（`animating(_:)`），无返回值的方法型调用也收成链方法
（`sizeToFit()` / `layoutIfNeeded()`）。覆盖范围优先常用属性；个别冷门或
易混淆的属性可用 `.also {}` 逃生口补齐。

> iOS 15 起被 UIButtonConfiguration 取代的 6 个旧式 UIButton API
> （contentEdgeInsets / titleEdgeInsets / imageEdgeInsets / adjustsImageWhenHighlighted /
> adjustsImageWhenDisabled / showsTouchWhenHighlighted）刻意不收：设置即触发弃用告警，
> 新式内边距/动画请走 `.configuration(...)` 或 `.also { $0.configuration = ... }`。

## 安装

SPM（本地路径或远端均可）：

```swift
// Package.swift
.package(url: "https://github.com/yourname/SwiftChainKit.git", from: "1.0.0")
// 或本地
.package(path: "../SwiftChainKit")

// target dependencies
.product(name: "SwiftChainKit", package: "SwiftChainKit")
```

Platform：iOS 15+。

## License

MIT，见 [LICENSE](LICENSE)。