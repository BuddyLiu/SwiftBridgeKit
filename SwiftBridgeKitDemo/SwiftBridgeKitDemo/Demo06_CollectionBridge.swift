//
//  Demo06_CollectionBridge.swift
//  SwiftBridgeKitDemo
//
//  Demo 06：网格 —— UICollectionView + 自定义 UICollectionViewCell
//
//  与 TableView 相同的边界认知：整个网格是一个 BridgeView，
//  单元格由 UIKit 复用池管理，不复用 BridgeCoordinator（见 Demo05 注释）。
//
//  这里示范**增量更新的正解**：用 UICollectionViewDiffableDataSource。
//    State.items → 每次 apply 只 apply(snapshot)，系统自动做 diff 动画，
//    而不是无脑 reloadData（会丢动画、闪一下）。
//  前提：CollectionItem 必须 Hashable（diffable 用它做 identity）。
//

import SwiftUI
import UIKit
import SwiftBridgeKit
import SwiftChainKit
import SnapKit

// MARK: - 契约层

// diffable 的 ItemIdentifierType 要求 Hashable & Sendable（须跨线程安全）。
// 本项目 defaultIsolation = MainActor：类型主体会被视为「主演员隔离」，
// 隔离类型无法充当 Sendable 泛型实参。正解：把 CollectionItem 显式声明为
// nonisolated 类型（纯值类型，不碰任何 UI，非隔离在语义上完全成立）。
nonisolated struct CollectionItem: Hashable & Sendable, BridgeState {
    var id: Int
    var label: String
    var hue: Double
}

struct CollectionState: BridgeState {
    var items: [CollectionItem]
}

enum CollectionIntent: BridgeIntent {
    case selected(CollectionItem)
}

// MARK: - 桥视图（整网格一个 BridgeView）

final class CollectionBridgeView: UIView, BridgeView, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    typealias State = CollectionState
    typealias Intent = CollectionIntent

    var onIntent: ((CollectionIntent) -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, CollectionItem>!
    private var items: [CollectionItem] = []
    private(set) var applyCount = 0
    private(set) var snapshotCount = 0

    override init(frame: CGRect) {
        super.init(frame: frame)

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout).chain()
            .delegate(self)
            .backgroundColor(.systemBackground)
            .register(CollectionItemCell.self, forCellWithReuseIdentifier: CollectionItemCell.reuseID)
            .added(to: self)
            .build()
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // diffable data source：闭包里只做「配置单元格」，不做数据逻辑
        dataSource = UICollectionViewDiffableDataSource<Int, CollectionItem>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CollectionItemCell.reuseID,
                for: indexPath
            ) as! CollectionItemCell
            cell.configure(with: item)
            return cell
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 320)
    }

    // MARK: - BridgeView

    func apply(_ state: CollectionState) {
        applyCount += 1

        // 内容没变就不重算 snapshot（配合 coordinator 的 state 早退，双层防线）
        guard items != state.items else {
            print("[CollDemo] apply \(applyCount) 但内容未变 → 跳过 snapshot（早退）")
            return
        }
        items = state.items
        snapshotCount += 1

        var snapshot = NSDiffableDataSourceSnapshot<Int, CollectionItem>()
        snapshot.appendSections([0])
        snapshot.appendItems(state.items)
        dataSource.apply(snapshot, animatingDifferences: true)
        print("[CollDemo] snapshot #\(snapshotCount) 共 \(state.items.count) 项")
    }

    func teardown() {
        collectionView.delegate = nil
        collectionView.dataSource = nil
        onIntent = nil
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < items.count else { return }
        let item = items[indexPath.item]
        print("[CollDemo] 点击 id=\(item.id)")
        onIntent?(.selected(item))
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let availableWidth = max(collectionView.bounds.width, 320)
        let insets = collectionView.safeAreaInsets.left + collectionView.safeAreaInsets.right
        let itemWidth = floor((availableWidth - insets - 8 * 3) / 3)
        return CGSize(width: itemWidth, height: itemWidth)
    }
}

// MARK: - 自定义单元格（复用 + prepareForReuse 归零）

@MainActor
final class CollectionItemCell: UICollectionViewCell {

    static let reuseID = "CollectionItemCell"

    /// 属性声明处链式创建：文字样式的四步配置收进一条链。
    private let label: UILabel = UILabel().chain()
        .textAlignment(.center)
        .font(.systemFont(ofSize: 12, weight: .medium))
        .numberOfLines(2)
        .textColor(.black)
        .build()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 8
        contentView.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.leading.equalToSuperview().offset(4)
            make.trailing.equalToSuperview().offset(-4)
            make.bottom.lessThanOrEqualToSuperview().offset(-6)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with item: CollectionItem) {
        backgroundColor = UIColor(hue: item.hue, saturation: 0.4, brightness: 0.92, alpha: 1)
        label.text = item.label
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        backgroundColor = .clear
        label.text = nil
    }
}

// MARK: - Demo 页面

struct Demo06_CollectionBridgePage: View {

    @State private var items: [CollectionItem] = {
        (0..<12).map {
            CollectionItem(id: $0, label: "项 \($0)", hue: Double($0) / 13)
        }
    }()
    @State private var itemID = 1000
    @State private var selected = "—"

    var body: some View {
        List {
            Section("UICollectionView + 复用单元格（diffable 增量）") {
                BridgeHost(
                    state: CollectionState(items: items),
                    makeView: { CollectionBridgeView() },
                    onIntent: { intent in
                        if case .selected(let item) = intent { selected = "#\(item.id) \(item.label)" }
                    }
                )
                .frame(height: 320)
                .listRowInsets(EdgeInsets())
            }

            Section("控制（看 diffable 动画）") {
                Button("随机加一项（末尾）") {
                    let item = CollectionItem(
                        id: itemID,
                        label: "新项 \(itemID)",
                        hue: Double(itemID % 20) / 20
                    )
                    itemID += 1
                    items.append(item)
                }
                Button("打乱顺序") { items.shuffle() }
                Button("清空") { items = [] }
                LabeledContent("已选", value: selected)
                Text("自检：加项/打乱 → 网格出现插入/移动动画（不是整屏闪一下）；不动数据时重绘 → 「跳过 snapshot（早退）」。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("06 · 网格（CollectionView）")
    }
}

#Preview {
    NavigationStack { Demo06_CollectionBridgePage() }
}
