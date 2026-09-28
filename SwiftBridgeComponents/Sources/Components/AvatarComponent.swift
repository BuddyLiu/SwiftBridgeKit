//
//  AvatarComponent.swift
//  SwiftBridgeComponents
//
//  头像 —— 纯展示组件：圆形 / 圆角方形，可带边框；无图时显示首字母占位。
//
//  ⚠️ 本组件是组件包里唯一在契约层带 UIKit 的：State 直接放 UIImage?。
//     （用户明确选择直接用 UIImage；换取 Equatable 的是「实例同一性」比较：
//       同一实例复用 → == 成立 → Coordinator 值比较早退 → 不重绘。）
//     若不想要这份耦合，可改存 Data?，代价是等值拷贝 + 主线程解码。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    title      → 首字母占位文案
//    image      → imageView 与占位 label 的显隐切换
//    shape/dimension → 圆角（circular 在 layoutSubviews 按实际 bounds 重算）+ invalidateIntrinsic
//    borderWidth/borderTone → layer 边框
//    showsStatusDot/statusDotTone → 右下角在线状态点（10pt + 白环，锚在 bounds 内防被裁）
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 头像的展示状态：图片或首字母占位 + 形态/尺寸 + 边框 + 在线状态点。
public struct AvatarState: BridgeState {
    /// 文案，无图时取首字母展示占位。
    public var title: String
    /// 头像图。nil = 显示首字母占位。
    public var image: UIImage?
    /// 显示形态：圆形或圆角方形。
    public var shape: AvatarShape
    /// 边长（pt）：决定 intrinsicContentSize 与 circular 圆角。
    public var dimension: CGFloat
    /// 边框宽度（pt），0 表示无边框。
    public var borderWidth: CGFloat
    /// 边框色调，nil 则不绘制边框。
    public var borderTone: ComponentTone?
    /// 右下角在线状态点。
    public var showsStatusDot: Bool
    /// 在线状态点的色调。
    public var statusDotTone: ComponentTone

    /// 用给定内容创建头像状态。
    ///
    /// title/image/shape 的初始值变化即触发对应子视图更新。
    /// - Parameters:
    ///   - title: 文案，无图时取首字母展示占位。
    ///   - image: 头像图，nil 显示首字母占位。
    ///   - shape: 显示形态，默认圆形。
    ///   - dimension: 边长，默认 40。
    ///   - borderWidth: 边框宽度，默认 0（无边框）。
    ///   - borderTone: 边框色调，默认 nil。
    ///   - showsStatusDot: 是否显示在线状态点，默认关闭。
    ///   - statusDotTone: 状态点色调，默认 success 绿色。
    public init(title: String,
                image: UIImage? = nil,
                shape: AvatarShape = .circular,
                dimension: CGFloat = 40,
                borderWidth: CGFloat = 0,
                borderTone: ComponentTone? = nil,
                showsStatusDot: Bool = false,
                statusDotTone: ComponentTone = .success) {
        self.title = title
        self.image = image
        self.shape = shape
        self.dimension = dimension
        self.borderWidth = borderWidth
        self.borderTone = borderTone
        self.showsStatusDot = showsStatusDot
        self.statusDotTone = statusDotTone
    }

    /// 值相等判定：纯值字段逐项比较，UIImage 按实例同一性判定。
    public static func == (lhs: AvatarState, rhs: AvatarState) -> Bool {
        lhs.title == rhs.title
            // UIImage 非 Equatable，用同一性：同一实例复用视为相等 → 早退生效
            && lhs.image === rhs.image
            && lhs.shape == rhs.shape
            && lhs.dimension == rhs.dimension
            && lhs.borderWidth == rhs.borderWidth
            && lhs.borderTone == rhs.borderTone
            && lhs.showsStatusDot == rhs.showsStatusDot
            && lhs.statusDotTone == rhs.statusDotTone
    }
}

// MARK: - 桥视图

/// 头像的桥视图：按 State 差异映射渲染，无图时显示首字母占位。
@MainActor
public final class AvatarBridgeView: UIView, BridgeView {

    /// 组件状态类型：头像状态。
    public typealias State = AvatarState
    /// 意图类型：纯展示组件无事件，用空意图 NoIntent。
    public typealias Intent = NoIntent

    /// 意图回调：本组件纯展示，目前无事件来源，保留通道便于扩展。
    public var onIntent: ((NoIntent) -> Void)?

    /// 每桥主题覆盖（运行时换肤）。nil = 回落全局 `ComponentTheme.current`。
    public var theme: (any BridgeTheme)?
    /// 上次解析生效的主题缓存：变化时强制重绘颜色（themeChanged）。
    private var cachedTheme: ComponentTheme?

    private let imageView = UIImageView()
    private let initialsLabel = UILabel()
    private let statusDot = UIView()
    private var cached: AvatarState?

    /// 初始化桥视图：装配头像图、首字母占位与在线状态点，并建立约束。
    override public init(frame: CGRect) {
        super.init(frame: frame)
        // view 自身：圆角裁 + 浅灰底（首字母占位底色）
        self.chain()
            .clipsToBounds(true)
            .backgroundColor(.systemGray5)

        // 无障碍：整个头像是一个读屏元素（label 由 apply 随 title 更新），
        // 头像内的 imageView / initialsLabel / statusDot 均被容器吸收、不单独暴露。
        isAccessibilityElement = true
        accessibilityTraits = [.image]

        // 头像图：拉伸填满；尺寸撑满容器走下方 SnapKit（translates 由它自动接管）
        imageView.chain()
            .contentMode(.scaleAspectFill)
            .added(to: self)

        initialsLabel.chain()
            .textAlignment(.center)
            .textColor(.secondaryLabel)
            .added(to: self)

        // 右下角状态点：10pt + 2pt 白环；锚在 bounds 内（父视图开了 clipsToBounds，
        // 探出边缘会被裁掉，所以内缩 2pt 而不是挂在角上）。
        // 底色不在这里写死：由 apply 用 resolvedTheme() 按 statusDotTone 解析（主题化）。
        statusDot.chain()
            .cornerRadius(ComponentMetrics.avatarStatusDotSize() / 2)
            .border(ComponentMetrics.avatarStatusDotRing(), color: .white)
            .isHidden(true)
            .added(to: self)

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        initialsLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        // 状态点：10pt 大小，锚在容器右下角（内缩 2pt 防被 clipsToBounds 裁掉）
        statusDot.snp.makeConstraints { make in
            make.size.equalTo(ComponentMetrics.avatarStatusDotSize())
            make.trailing.bottom.equalTo(self).inset(ComponentMetrics.avatarStatusDotInset())
        }
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 按缓存 State 的 dimension 返回正方形尺寸，供自动布局确定大小。
    override public var intrinsicContentSize: CGSize {
        let d = cached?.dimension ?? 40
        return CGSize(width: d, height: d)
    }

    /// 布局时按实际 bounds 重算圆角：circular 取宽度一半，roundedRect 用固定比例。
    override public func layoutSubviews() {
        super.layoutSubviews()
        guard let state = cached else { return }
        // circular 的圆角必须用实际 bounds 的一半，比例拉伸时也不会跑偏；
        // roundedRect 用固定的 0.28 倍尺寸。
        layer.cornerRadius = ComponentMetrics.avatarCornerRadius(shape: state.shape, dimension: bounds.width)
    }

    // MARK: - BridgeView

    /// 把 State 快照差异映射到视图上。
    public func apply(_ state: AvatarState) {
        // 主题解析：每桥覆盖优先，否则回落全局 current；themeChanged 时强制重绘颜色
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme
        let prev = cached
        cached = state

        if prev?.title != state.title {
            initialsLabel.text = String(state.title.prefix(1)).uppercased()
            initialsLabel.font = ComponentTypography.initialsFont(dimension: state.dimension)
            // 单元素读屏：label 用完整姓名（首字母只是视觉占位）；空标题回退系统默认
            accessibilityLabel = state.title.isEmpty ? nil : state.title
        }
        if prev?.image !== state.image {
            imageView.image = state.image
            let hasImage = state.image != nil
            imageView.isHidden = !hasImage
            initialsLabel.isHidden = hasImage
        }
        if prev?.dimension != state.dimension {
            initialsLabel.font = ComponentTypography.initialsFont(dimension: state.dimension)
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
        if prev?.shape != state.shape {
            setNeedsLayout()
        }
        if themeChanged || prev?.borderWidth != state.borderWidth || prev?.borderTone != state.borderTone {
            layer.borderWidth = state.borderWidth
            layer.borderColor = state.borderTone.map { theme.color(for: $0).cgColor }
        }
        if themeChanged || prev?.statusDotTone != state.statusDotTone {
            statusDot.backgroundColor = theme.color(for: state.statusDotTone)
        }
        if prev?.showsStatusDot != state.showsStatusDot {
            statusDot.isHidden = !state.showsStatusDot
        }
    }

    /// 拆除桥视图：断开意图通道，释放对外引用。
    public func teardown() {
        onIntent = nil
    }
}