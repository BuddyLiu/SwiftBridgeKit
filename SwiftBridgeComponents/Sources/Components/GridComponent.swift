//
//  GridComponent.swift
//  SwiftBridgeComponents
//
//  宫格按钮 —— 交互容器：soft tone 圆角块 + SF icon + 标题，列数可配。
//  吸收 Demo06 的 CollectionView 边界认知 + diffable 增量更新的正解：
//    每页 State.cells 变了才 apply(snapshot)，系统自动做插入/移动动画；
//    值模型必须 Hashable（diffable 用 identity），纯值类型天然 Sendable。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    cells   → 集合级早退 + diffable 增量快照（不无脑 reloadData）
//    columns → flow layout 的 item 尺寸（变化即触发重排）
//  点击格只上报 .tapped(cell)，跳转等动作由业务决定（保持「唯一真相」）。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 一格数据。Hashable & Sendable：diffable 的 ItemIdentifierType 需要。
public struct GridCell: Hashable & Sendable {
    /// 格唯一标识：diffable 增量更新用的 identity。
    public var id: String
    /// 主标题，居中显示在图标下方。
    public var title: String
    /// SF Symbol 名；nil = 不显示图标，只留标题。
    public var icon: String?
    /// 配色主题：底色 / 文字 / 图标配色。
    public var tone: ComponentTone
    /// 右上角红色小角标（如 "new" / 未读数）；nil = 不显示。
    public var badge: String?

    /// 构造一格数据。
    /// - Parameters:
    ///   - id: 格唯一标识（diffable identity）。
    ///   - title: 主标题。
    ///   - icon: SF Symbol 名；默认 nil（不显示图标）。
    ///   - tone: 配色主题；默认 .primary。
    ///   - badge: 右上角角标文案；默认 nil（不显示）。
    public init(id: String,
                title: String,
                icon: String? = nil,
                tone: ComponentTone = .primary,
                badge: String? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.tone = tone
        self.badge = badge
    }
}

/// 宫格按钮的展示状态：格子数据 + 列数。
public struct GridState: BridgeState {
    /// 格子数据（Hashable & Sendable，供 diffable 增量更新）。
    public var cells: [GridCell]
    /// 每行列数。构造时钳到至少 1。
    public var columns: Int

    /// 构造宫格状态。
    /// - Parameters:
    ///   - cells: 格子数据。
    ///   - columns: 每行列数；默认 3（构造时钳到至少 1）。
    public init(cells: [GridCell], columns: Int = 3) {
        self.cells = cells
        self.columns = max(columns, 1)
    }
}

/// 宫格交互意图：点击某一格。
public enum GridIntent: BridgeIntent {
    /// 点击了某一格，携带该格数据（跳转等动作由业务决定）。
    case tapped(GridCell)
}

// MARK: - 桥视图

/// 宫格按钮桥视图：soft tone 圆角块 + SF icon + 标题，列数可配；
/// 用 diffable 做增量更新（不无脑 reloadData），点击只上报意图。
@MainActor
public final class GridBridgeView: UIView, BridgeView, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    /// 桥状态类型：格子数据 + 列数。
    public typealias State = GridState
    /// 桥意图类型：点击某一格。
    public typealias Intent = GridIntent

    /// 意图上抛回调：点击某一格。
    public var onIntent: ((GridIntent) -> Void)?

    /// internal（非 private）：留给 @testable 冒烟测试校验 item 尺寸用。
    var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, GridCell>!
    private var cells: [GridCell] = []
    private var columns: Int = 3

    /// 构造组件：搭好 flow layout、collectionView 与 diffable data source，并注册单元格。
    /// - Parameters:
    ///   - frame: 初始 frame。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        collectionView = UICollectionView.chain(layout: layout)
            .delegate(self)
            .backgroundColor(.clear)
            .register(GridItemCell.self, forCellWithReuseIdentifier: GridItemCell.reuseID)
            .added(to: self)
            .build()

        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // diffable data source：闭包里只做「配置单元格」，不做数据逻辑
        dataSource = UICollectionViewDiffableDataSource<Int, GridCell>(
            collectionView: collectionView
        ) { collectionView, indexPath, cell in
            let item = collectionView.dequeueReusableCell(
                withReuseIdentifier: GridItemCell.reuseID,
                for: indexPath
            ) as! GridItemCell
            item.configure(with: cell)
            return item
        }
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：宽不固定，高固定 300（宫格总高）。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 300)
    }

    // MARK: - BridgeView

    /// 应用最新状态：列数变化重排（invalidateLayout）；cells 变化走 diffable 增量快照，
    /// 内容没变就早退（配合 coordinator 的双层防线）。
    /// - Parameters:
    ///   - state: 最新的宫格状态。
    public func apply(_ state: GridState) {
        if columns != state.columns {
            columns = state.columns
            // 列数变了必须重排：flow layout 的 item 尺寸只在布局 pass 重算，
            // 数据没变时（cells 早退）不会自动 invalidate，否则改列数画面纹丝不动。
            collectionView.collectionViewLayout.invalidateLayout()
        }

        // 内容没变就不重算 snapshot（配合 coordinator 的 state 早退，双层防线）
        guard cells != state.cells else { return }
        cells = state.cells

        var snapshot = NSDiffableDataSourceSnapshot<Int, GridCell>()
        snapshot.appendSections([0])
        snapshot.appendItems(state.cells)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    /// 拆桥：断 delegate、置空 dataSource 与意图回调。
    public func teardown() {
        collectionView.delegate = nil
        dataSource = nil
        onIntent = nil
    }

    // MARK: - UICollectionViewDelegate

    /// 选中某格：上报 .tapped(cell)，跳转等动作由业务决定。
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < cells.count else { return }
        onIntent?(.tapped(cells[indexPath.item]))
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    /// 计算格子尺寸：按列数把可用宽切成等宽方块（宽高一致，图标 + 标题竖排装得下）。
    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let layout = collectionViewLayout as! UICollectionViewFlowLayout
        let availableWidth = max(collectionView.bounds.width, 320)
        let insets = layout.sectionInset.left + layout.sectionInset.right
        let spacing = layout.minimumInteritemSpacing * CGFloat(columns - 1)
        let itemWidth = floor((availableWidth - insets - spacing) / CGFloat(columns))
        // 方形格：宽高一致，图标 + 标题竖排装得下
        return CGSize(width: itemWidth, height: itemWidth)
    }
}

// MARK: - 单元格

@MainActor
private final class GridItemCell: UICollectionViewCell {

    static let reuseID = "GridItemCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let badgeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.chain().cornerRadius(ComponentMetrics.gridCellCorner())

        iconView.chain()
            .contentMode(.scaleAspectFit)
            .added(to: contentView)

        titleLabel.chain()
            .font(ComponentTypography.gridTitleFont())
            .textAlignment(.center)
            .numberOfLines(1)
            .adjustsFontSizeToFitWidth(true)
            .minimumScaleFactor(0.7)
            .added(to: contentView)

        // 右上角红色角标：文字白、底 systemRed、pill 小圆角
        badgeLabel.chain()
            .font(ComponentTypography.gridBadgeFont())
            .textColor(.white)
            .backgroundColor(.systemRed)
            .textAlignment(.center)
            .clipsToBounds(true)
            .cornerRadius(ComponentMetrics.gridBadgeHeight() / 2)
            .isHidden(true)
            .added(to: contentView)

        iconView.snp.makeConstraints { make in
            make.centerX.equalTo(contentView)
            make.centerY.equalTo(contentView).offset(-8)
            make.size.equalTo(ComponentMetrics.gridIconSize())
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(contentView).offset(4)
            make.trailing.equalTo(contentView).offset(-4)
            make.bottom.equalTo(contentView).offset(-10)
        }

        badgeLabel.snp.makeConstraints { make in
            make.top.equalTo(contentView).offset(4)
            make.trailing.equalTo(contentView).offset(-4)
            make.height.equalTo(ComponentMetrics.gridBadgeHeight())
            make.width.greaterThanOrEqualTo(ComponentMetrics.gridBadgeHeight())
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with cell: GridCell) {
        backgroundColor = ComponentPalette.softBackground(for: cell.tone)
        titleLabel.text = cell.title
        titleLabel.textColor = ComponentPalette.color(for: cell.tone)
        iconView.image = cell.icon.flatMap { UIImage(systemName: $0) }
        iconView.tintColor = ComponentPalette.color(for: cell.tone)
        if let badge = cell.badge {
            badgeLabel.text = badge
            badgeLabel.isHidden = false
        } else {
            badgeLabel.text = nil
            badgeLabel.isHidden = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        backgroundColor = .clear
        iconView.image = nil
        titleLabel.text = nil
        badgeLabel.text = nil
        badgeLabel.isHidden = true
    }
}