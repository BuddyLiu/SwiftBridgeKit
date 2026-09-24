//
//  ListComponent.swift
//  SwiftBridgeComponents
//
//  通用列表 —— 交互容器：系统样式行（icon 圆角块 + 标题/副文案 + 尾部文案/箭头），
//  吸收 Demo05 的 TableView 边界认知：整个表是一个 BridgeView，单元格由 UIKit
//  复用池管理，不复用 BridgeCoordinator。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    rows → 行级早退 + **diffable 增量快照**（升级对齐 Grid：增删移动带系统动画，
//           不复把整表 reloadData；行模型 ListRow 本身 Hashable，天然当 identifier）
//  点击行只上报 .selected(row)、滑动动作只上报 .swipeAction(row, action)，
//  其余动作（含真正删行）由业务决定（保持「唯一真相」）。
//
//  ⚠️ 复用池是长寿命对象：teardown 必须断 delegate/dataSource + 置空 dataSource
//     引用，否则拆桥后 UIKit 仍会回调，这是最经典的野指针来源。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 一行可配置的滑动操作（如删除）。纯值模型（Hashable），可进 == 判定。
public struct ListSwipeAction: Hashable, Sendable {
    /// 操作唯一标识，供业务区分是哪一个滑动操作。
    public var id: String
    /// 按钮上显示的文案。
    public var title: String
    /// 操作按钮的背景色调。
    public var tone: ComponentTone

    /// 创建一个左滑操作。
    /// - Parameters:
    ///   - id: 操作唯一标识。
    ///   - title: 按钮显示文案。
    ///   - tone: 按钮背景色调，默认 `.danger`（删除语义）。
    public init(id: String,
                title: String,
                tone: ComponentTone = .danger) {
        self.id = id
        self.title = title
        self.tone = tone
    }
}

/// 一行数据。纯值模型（Hashable），进「值比较早退」的 == 判定。
/// Sendable：ListRow 进 diffable 的 ItemIdentifierType，对齐 GridCell 的双重身份。
public struct ListRow: Hashable, Sendable {
    /// 行唯一标识，作为 diffable 的 identifier。
    public var id: String
    /// 主标题文案。
    public var title: String
    /// 副标题文案；nil = 不显示副标题。
    public var subtitle: String?
    /// SF Symbol 名；nil = 不显示 leading 图标。
    public var leadingIcon: String?
    /// leading 图标的色调（浅底 + 图标色都取自它）。
    public var tone: ComponentTone
    /// 尾部文案；nil = 不显示。
    public var trailingText: String?
    /// 是否显示右侧箭头。
    public var showsChevron: Bool
    /// 左滑出现的操作；空数组 = 不可滑。
    public var swipeActions: [ListSwipeAction]

    /// 创建一行数据。
    /// - Parameters:
    ///   - id: 行唯一标识。
    ///   - title: 主标题文案。
    ///   - subtitle: 副标题文案，默认 nil（不显示）。
    ///   - leadingIcon: leading 图标 SF Symbol 名，默认 nil（不显示图标）。
    ///   - tone: 图标与浅底的色调，默认 `.primary`。
    ///   - trailingText: 尾部文案，默认 nil（不显示）。
    ///   - showsChevron: 是否显示右侧箭头，默认 `true`。
    ///   - swipeActions: 左滑操作列表，默认空数组（不可滑）。
    public init(id: String,
                title: String,
                subtitle: String? = nil,
                leadingIcon: String? = nil,
                tone: ComponentTone = .primary,
                trailingText: String? = nil,
                showsChevron: Bool = true,
                swipeActions: [ListSwipeAction] = []) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = leadingIcon
        self.tone = tone
        self.trailingText = trailingText
        self.showsChevron = showsChevron
        self.swipeActions = swipeActions
    }
}

/// 列表的整份数据快照：一行一个 `ListRow`，整体替换后由 diffable 做增量差分。
public struct ListState: BridgeState {
    /// 全部行，按数组顺序自上而下展示。
    public var rows: [ListRow]

    /// 创建列表状态。
    /// - Parameter rows: 全部行数据，数组顺序即展示顺序。
    public init(rows: [ListRow]) {
        self.rows = rows
    }
}

/// 列表上报给业务的事件：点击选中 / 左滑操作。
public enum ListIntent: BridgeIntent {
    /// 点击某一行，携带该行数据。
    case selected(ListRow)
    /// 左滑触发某操作，携带行与操作；真正删行由业务决定。
    case swipeAction(ListRow, ListSwipeAction)
}

// MARK: - 桥视图

@MainActor
/// 通用列表的桥视图：diffable 增量快照驱动整个 TableView，行级早退双保险；点选/滑动只上报意图。
public final class ListBridgeView: UIView, BridgeView, UITableViewDelegate {

    /// 桥状态：整份行快照。
    public typealias State = ListState
    /// 桥上报事件：选中与滑动操作。
    public typealias Intent = ListIntent

    /// 事件上报通道：点击行上报 `.selected`，左滑上报 `.swipeAction`。
    public var onIntent: ((ListIntent) -> Void)?

    private let tableView = UITableView(frame: .zero, style: .plain)
    /// diffable data source：行模型 Hashable，天然适配 ItemIdentifierType。
    /// 闭包里只做「配置单元格」，不做数据逻辑。
    private var dataSource: UITableViewDiffableDataSource<Int, ListRow>!
    /// 业务回写的最近行快照，供 delegate 回调按 indexPath 取行。
    private var rows: [ListRow] = []

    /// 创建列表桥视图：注册 `ListRowCell` 复用并配置 diffable dataSource。
    override public init(frame: CGRect) {
        super.init(frame: frame)

tableView.chain()
            .delegate(self)
            .register(ListRowCell.self, forCellReuseIdentifier: ListRowCell.reuseID)
            .rowHeight(ComponentMetrics.listRowHeight())
            .separatorInset(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0))
            .added(to: self)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        dataSource = UITableViewDiffableDataSource<Int, ListRow>(tableView: tableView) {
            tableView, indexPath, row in
            let cell = tableView.dequeueReusableCell(withIdentifier: ListRowCell.reuseID, for: indexPath) as! ListRowCell
            cell.configure(with: row)
            return cell
        }
    }

    @available(*, unavailable)
    /// 不支持：仅满足 NSCoding 编译要求。
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 高度给 300 基线，宽度交由外部布局；业务可用约束覆盖。
    override public var intrinsicContentSize: CGSize {
        // 高度给个常见基线，业务可用 .frame 覆盖
        CGSize(width: UIView.noIntrinsicMetric, height: 300)
    }

    // MARK: - BridgeView

    /// 应用新状态：rows 行级早退 + diffable 增量快照（增删移动带系统动画）。
    public func apply(_ state: ListState) {
        // 行级早退：rows 集合没变就跳过 snapshot（配合 coordinator 的整体早退，双层防线）
        guard rows != state.rows else { return }
        rows = state.rows

        var snapshot = NSDiffableDataSourceSnapshot<Int, ListRow>()
        snapshot.appendSections([0])
        snapshot.appendItems(state.rows)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    /// 拆桥：断 delegate/dataSource 并清内部引用，防止复用池在拆桥后回调造成野指针。
    public func teardown() {
        // 复用池长寿命对象：断 delegate/dataSource + 清内部引用，再清上报通道
        tableView.delegate = nil
        tableView.dataSource = nil
        dataSource = nil
        onIntent = nil
    }

    // MARK: - UITableViewDelegate

    /// 点击行：先反选，再上报 `.selected`。
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < rows.count else { return }
        onIntent?(.selected(rows[indexPath.row]))
    }

    /// 左滑操作：行无 swipeActions 时返回 nil（整行不可滑）。
    public func tableView(_ tableView: UITableView,
                          trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < rows.count else { return nil }
        let row = rows[indexPath.row]
        guard !row.swipeActions.isEmpty else { return nil }

        let actions = row.swipeActions.map { swipe in
            let action = UIContextualAction(style: .destructive, title: swipe.title) { [weak self] _, _, completion in
                // 只上报意图：真正删行由业务决定，回传新 State 再差分 reload
                self?.onIntent?(.swipeAction(row, swipe))
                completion(true)
            }
            action.backgroundColor = ComponentPalette.color(for: swipe.tone)
            return action
        }
        return UISwipeActionsConfiguration(actions: actions)
    }
}

// MARK: - 单元格

/// 复用池内自成一格：configure 写入；prepareForReuse 归零，防脏复用。
@MainActor
private final class ListRowCell: UITableViewCell {

    static let reuseID = "ListRowCell"

    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let trailingLabel = UILabel()
    private let chevronView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        iconContainer.chain()
            .cornerRadius(8)
            .clipsToBounds(true)
            .added(to: contentView)

        iconView.chain()
            .contentMode(.scaleAspectFit)
            .added(to: iconContainer)

        titleLabel.chain()
            .font(.systemFont(ofSize: 15, weight: .medium))
            .added(to: contentView)

        subtitleLabel.chain()
            .font(.systemFont(ofSize: 13))
            .textColor(.secondaryLabel)
            .added(to: contentView)

        trailingLabel.chain()
            .font(.systemFont(ofSize: 13))
            .textColor(.secondaryLabel)
            .hugging(.required, for: .horizontal)
            .added(to: contentView)

        chevronView.chain()
            .symbol("chevron.right")
            .tintColor(.separator)
            .hugging(.required, for: .horizontal)
            .added(to: contentView)

        iconContainer.snp.makeConstraints { make in
            make.leading.equalTo(contentView).offset(16)
            make.centerY.equalTo(contentView)
            make.size.equalTo(28)
        }
        iconView.snp.makeConstraints { make in
            make.centerX.centerY.equalTo(iconContainer)
            make.size.equalTo(16)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconContainer.snp.trailing).offset(12)
            make.top.equalTo(contentView).offset(9)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.leading)
            make.top.equalTo(titleLabel.snp.bottom).offset(1)
            make.trailing.lessThanOrEqualTo(trailingLabel.snp.leading).offset(-8)
        }

        trailingLabel.snp.makeConstraints { make in
            make.trailing.equalTo(chevronView.snp.leading).offset(-6)
            make.centerY.equalTo(contentView)
        }

        chevronView.snp.makeConstraints { make in
            make.trailing.equalTo(contentView).offset(-16)
            make.centerY.equalTo(contentView)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with row: ListRow) {
        let color = ComponentPalette.color(for: row.tone)

        if let icon = row.leadingIcon {
            iconContainer.isHidden = false
            iconContainer.backgroundColor = ComponentPalette.softBackground(for: row.tone)
            iconView.tintColor = color
            iconView.image = UIImage(systemName: icon)
        } else {
            iconContainer.isHidden = true
        }

        titleLabel.text = row.title
        titleLabel.textColor = .label
        subtitleLabel.text = row.subtitle
        subtitleLabel.isHidden = row.subtitle == nil
        trailingLabel.text = row.trailingText
        trailingLabel.isHidden = row.trailingText == nil
        chevronView.isHidden = !row.showsChevron
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.image = nil
        iconContainer.backgroundColor = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
        trailingLabel.text = nil
    }
}
