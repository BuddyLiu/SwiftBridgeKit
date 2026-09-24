//
//  Demo05_TableBridge.swift
//  SwiftBridgeKitDemo
//
//  Demo 05：列表 —— UITableView + 自定义 UITableViewCell
//
//  这一类视图的关键认知：
//    **单元格不各自拥有 BridgeCoordinator**。整个表是一个 BridgeView，
//    单元格是表的「内部实现」，由 UIKit 的 dequeue/reuse 机制管理。
//    BridgeView 抽象覆盖的是「配 UIKit 组件」，不覆盖「配 UIKit 复用池」——
//    复用池内部仍用 UIKit 原生语义，这恰恰是桥的正确边界。
//
//  承接关系：
//    State.rows（SwiftUI 唯一真相）→ apply → reloadData / cellForRow configure
//    点击行 → didSelectRowAt → onIntent → 业务
//
//  两个容易写错的地方：
//    1. apply 里「内容没变就不 reload」（coordinator 已对整体 state 早退，
//       但 page 里任何 @State 变化都会让 updateUIView 进来，所以要再兜一层行级比较）。
//    2. teardown 必须 delegate/dataSource = nil —— 列表是长寿命对象，
//       拆桥后 UIKit 仍可能回调，这是最经典的野指针来源。
//

import SwiftUI
import UIKit
import SwiftBridgeKit
import SwiftChainKit
import SnapKit

// MARK: - 契约层

struct TableRow: BridgeState {
    var id: Int
    var title: String
    var subtitle: String
}

struct TableState: BridgeState {
    var rows: [TableRow]
}

enum TableIntent: BridgeIntent {
    case selected(TableRow)
}

// MARK: - 桥视图（整个表是一个 BridgeView）

final class TableBridgeView: UIView, BridgeView, UITableViewDataSource, UITableViewDelegate {

    typealias State = TableState
    typealias Intent = TableIntent

    var onIntent: ((TableIntent) -> Void)?

    // ⚠️ 外层 SwiftUI List 已是 insetedGrouped（分组卡片），
    //    桥里的表若再用 .insetGrouped 就是「组中组」——cell 左右缩进、上下留白。
    //    这里用 .plain：cell 顶满整宽、无系统分组间距，正好贴合外层卡片边缘。
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var rows: [TableRow] = []
    private(set) var applyCount = 0
    private(set) var reloadCount = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        // 链式创建：dataSource/delegate/register 一条链收完，再挂到 self 上
        tableView.chain()
            .dataSource(self)
            .delegate(self)
            .register(TableRowCell.self, forCellReuseIdentifier: TableRowCell.reuseID)
            .added(to: self)
            .build()
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// SwiftUI 侧需要一个确定高度（List 行内不会自动撑满）。
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 380)
    }

    // MARK: - BridgeView

    func apply(_ state: TableState) {
        applyCount += 1

        // 行级差异判断：内容没变就不 reload（省一次全表刷新 + 滚动抖动）
        guard rows != state.rows else {
            print("[TableDemo] apply \(applyCount) 但行内容未变 → 跳过 reload（早退）")
            return
        }
        rows = state.rows
        reloadCount += 1
        tableView.reloadData()
        print("[TableDemo] reload #\(reloadCount) 共 \(rows.count) 行")
    }

    func teardown() {
        // ⚠️ 长寿命装饰器的断连：必须先断 delegate/dataSource，再断通道
        tableView.delegate = nil
        tableView.dataSource = nil
        onIntent = nil
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableRowCell.reuseID, for: indexPath) as! TableRowCell
        cell.configure(with: rows[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rows[indexPath.row]
        print("[TableDemo] 点击 id=\(row.id) title=\(row.title)")
        onIntent?(.selected(row))
    }
}

// MARK: - 自定义单元格（复用 + prepareForReuse 归零）

@MainActor
final class TableRowCell: UITableViewCell {

    static let reuseID = "TableRowCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        textLabel?.font = .systemFont(ofSize: 15)
        detailTextLabel?.font = .systemFont(ofSize: 12)
        detailTextLabel?.textColor = .secondaryLabel
        accessoryType = .disclosureIndicator
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with row: TableRow) {
        textLabel?.text = row.title
        detailTextLabel?.text = row.subtitle
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // 复用归零：否则快速滚动时会把上一行的内容带到新行
        textLabel?.text = nil
        detailTextLabel?.text = nil
    }
}

// MARK: - Demo 页面

struct Demo05_TableBridgePage: View {

    @State private var rows: [TableRow] = {
        (0..<8).map { TableRow(id: $0, title: "标题 \($0)", subtitle: "子标题，点我试试") }
    }()
    @State private var rowID = 1000
    @State private var selected = "—"

    var body: some View {
        List {
            Section("UITableView + 复用单元格") {
                BridgeHost(
                    state: TableState(rows: rows),
                    makeView: { TableBridgeView() },
                    onIntent: { intent in
                        if case .selected(let row) = intent { selected = "#\(row.id) \(row.title)" }
                    }
                )
                .padding(0)
                .frame(height: 380)
                .cornerRadius(8)
                .listRowInsets(EdgeInsets())
            }

            Section("控制（验证 reload 早退）") {
                Button("随机加一行（头部）") {
                    let newRow = TableRow(id: rowID, title: "新行 \(rowID)", subtitle: "随机数据")
                    rowID += 1
                    rows.insert(newRow, at: 0)
                }
                Button("删掉第一行") {
                    if !rows.isEmpty { rows.removeFirst() }
                }
                LabeledContent("已选", value: selected)
                Text("自检：加/删行 → 控制台 reload；不动数据时，点其它开关让页面重绘 → 应出现「跳过 reload（早退）」。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("05 · 列表（TableView）")
    }
}

#Preview {
    NavigationStack { Demo05_TableBridgePage() }
}
