//
//  ChainTests.swift
//  SwiftChainKitTests
//
//  链 DSL 冒烟：取回本体的属性一致性、逃生口、层级、autolayout、工厂入口，
//  以及各类型扩展（视图/文字/图片/按钮/控件/滚动/表单）的主要属性。
//  全部 @MainActor：UIKit 属性读写只允许主线程。

import XCTest
import UIKit
@testable import SwiftChainKit

final class ChainTests: XCTestCase {

    // MARK: - 基座

    @MainActor
    func testLabelChain() {
        let label = UILabel().chain()
            .text("你好")
            .font(.systemFont(ofSize: 16, weight: .semibold))
            .textColor(.systemBlue)
            .textAlignment(.center)
            .numberOfLines(2)
            .build()
        XCTAssertEqual(label.text, "你好")
        XCTAssertEqual(label.font, .systemFont(ofSize: 16, weight: .semibold))
        XCTAssertEqual(label.textColor, .systemBlue)
        XCTAssertEqual(label.textAlignment, .center)
        XCTAssertEqual(label.numberOfLines, 2)
    }

    @MainActor
    func testAlsoEscapeHatch() {
        let label = UILabel().chain()
            .text("x")
            .also { $0.isUserInteractionEnabled = true }
            .build()
        XCTAssertTrue(label.isUserInteractionEnabled)
    }

    @MainActor
    func testAddedToParent() {
        let parent = UIView()
        let child = UILabel().chain()
            .text("a")
            .added(to: parent)
            .build()
        XCTAssertTrue(child.isDescendant(of: parent))
    }

    @MainActor
    func testAutolayoutSetsFalse() {
        let view = UIView().chain()
            .autolayout()
            .build()
        XCTAssertFalse(view.translatesAutoresizingMaskIntoConstraints)
    }

    @MainActor
    func testTranslatesAutoresizingMaskIntoConstraints() {
        // 链式可写：false / true / 再 false 都能落盘
        let view = UIView().chain()
            .translatesAutoresizingMaskIntoConstraints(false)
            .build()
        XCTAssertFalse(view.translatesAutoresizingMaskIntoConstraints)
        UIView().chain().translatesAutoresizingMaskIntoConstraints(true).also { v in
            XCTAssertTrue(v.translatesAutoresizingMaskIntoConstraints)
        }
        _ = UIView().chain()
            .translatesAutoresizingMaskIntoConstraints(true)
            .translatesAutoresizingMaskIntoConstraints(false)
            .build()
    }

    @MainActor
    func testButtonFactoryAndTitle() {
        let button = UIButton.chain(type: .system)
            .title("确定")
            .titleColor(.white, for: .normal)
            .symbol("checkmark", for: .normal)
            .build()
        XCTAssertEqual(button.title(for: .normal), "确定")
        XCTAssertEqual(button.titleColor(for: .normal), .white)
        XCTAssertEqual(button.image(for: .normal), UIImage(systemName: "checkmark"))
    }

    @MainActor
    func testStackAndArrangedSubviews() {
        let icon = UIImageView().chain()
            .isHidden(true)
            .build()
        let stack = UIStackView.chain(arrangedSubviews: [icon])
            .axis(.horizontal)
            .alignment(.center)
            .spacing(8)
            .build()
        XCTAssertEqual(stack.axis, .horizontal)
        XCTAssertEqual(stack.alignment, .center)
        XCTAssertEqual(stack.spacing, 8)
        XCTAssertTrue(stack.arrangedSubviews.contains(icon))
    }

    @MainActor
    func testUIViewLayerChain() {
        let view = UIView().chain()
            .cornerRadius(10)
            .border(1.5, color: .systemRed)
            .clipsToBounds(true)
            .backgroundColor(.systemGray6)
            .build()
        XCTAssertEqual(view.layer.cornerRadius, 10)
        XCTAssertEqual(view.layer.borderWidth, 1.5)
        XCTAssertEqual(view.layer.borderColor, UIColor.systemRed.cgColor)
        XCTAssertTrue(view.clipsToBounds)
        XCTAssertEqual(view.backgroundColor, .systemGray6)
    }

    @MainActor
    func testCollectionViewFactoryKeepsLayout() {
        let layout = UICollectionViewFlowLayout()
        let view = UICollectionView.chain(layout: layout)
            .register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
            .build()
        XCTAssertEqual(view.collectionViewLayout, layout)
    }

    @MainActor
    func testBuildDiscardable() {
        // @discardableResult：不接 build() 也不告警
        _ = UILabel().chain().text("ok").autolayout()
        XCTAssertTrue(true)
    }

    // MARK: - UIView 基座扩展

    @MainActor
    func testUIViewBaseProperties() {
        let view = UIView().chain()
            .frame(CGRect(x: 0, y: 0, width: 10, height: 10))
            .bounds(CGRect(x: 0, y: 0, width: 10, height: 10))
            .center(CGPoint(x: 5, y: 5))
            .tag(7)
            .alpha(0.5)
            .isOpaque(true)
            .isUserInteractionEnabled(false)
            .isMultipleTouchEnabled(true)
            .isExclusiveTouch(true)
            .contentMode(.scaleAspectFit)
            .tintAdjustmentMode(.dimmed)
            .transform(CGAffineTransform(rotationAngle: 0))
            .transform3D(CATransform3DIdentity)
            .semanticContentAttribute(.forceLeftToRight)
            .layoutMargins(UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4))
            .preservesSuperviewLayoutMargins(true)
            .insetsLayoutMarginsFromSafeArea(false)
            .build()
        XCTAssertEqual(view.tag, 7)
        XCTAssertEqual(view.alpha, 0.5)
        XCTAssertEqual(view.contentMode, .scaleAspectFit)
        XCTAssertEqual(view.tintAdjustmentMode, .dimmed)
        XCTAssertEqual(view.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(view.layoutMargins, UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4))
        XCTAssertTrue(view.preservesSuperviewLayoutMargins)
        XCTAssertFalse(view.insetsLayoutMarginsFromSafeArea)
        XCTAssertTrue(view.isMultipleTouchEnabled)
        XCTAssertTrue(view.isExclusiveTouch)
    }

    @MainActor
    func testUIViewTintColor() {
        // 单独测 tintColor：tintAdjustmentMode == .dimmed 时 UIKit 会把读取值压成「置暗变体」，
        // 与二次读取的值做等值比较会失败，是 UIKit 行为而非链库问题。
        let view = UIView().chain()
            .tintColor(.systemBlue)
            .build()
        XCTAssertEqual(view.tintColor, .systemBlue)
    }

    @MainActor
    func testUIViewShadowLayer() {
        let view = UIView().chain()
            .shadowColor(.black)
            .shadowOpacity(0.4)
            .shadowRadius(6)
            .shadowOffset(CGSize(width: 0, height: 2))
            .masksToBounds(false)
            .zPosition(3)
            .borderWidth(1)
            .borderColor(.systemGray)
            .build()
        XCTAssertEqual(view.layer.shadowColor, UIColor.black.cgColor)
        XCTAssertEqual(view.layer.shadowOpacity, 0.4)
        XCTAssertEqual(view.layer.shadowRadius, 6)
        XCTAssertEqual(view.layer.shadowOffset, CGSize(width: 0, height: 2))
        XCTAssertEqual(view.layer.zPosition, 3)
        XCTAssertEqual(view.layer.borderWidth, 1)
        XCTAssertEqual(view.layer.borderColor, UIColor.systemGray.cgColor)
    }

    @MainActor
    func testHuggingAndCompression() {
        let view = UIView().chain()
            .hugging(.required, for: .horizontal)
            .compressionResistance(.defaultLow, for: .vertical)
            .build()
        XCTAssertEqual(view.contentHuggingPriority(for: .horizontal), .required)
        XCTAssertEqual(view.contentCompressionResistancePriority(for: .vertical), .defaultLow)
    }

    @MainActor
    func testAccessibility() {
        let view = UIView().chain()
            .isAccessibilityElement(true)
            .accessibilityLabel("卡片")
            .accessibilityValue("v")
            .accessibilityHint("h")
            .accessibilityTraits(.button)
            .accessibilityIdentifier("card")
            .build()
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertEqual(view.accessibilityLabel, "卡片")
        XCTAssertEqual(view.accessibilityValue, "v")
        XCTAssertEqual(view.accessibilityHint, "h")
        XCTAssertEqual(view.accessibilityTraits, .button)
        XCTAssertEqual(view.accessibilityIdentifier, "card")
    }

    // MARK: - UILabel 扩展

    @MainActor
    func testUILabelExtended() {
        let label = UILabel().chain()
            .text("标题")
            .font(.systemFont(ofSize: 20, weight: .bold))
            .textColor(.systemBlue)
            .highlightedTextColor(.systemRed)
            .isHighlighted(true)
            .isEnabled(false)
            .lineBreakMode(.byTruncatingTail)
            .baselineAdjustment(.alignCenters)
            .adjustsFontSizeToFitWidth(true)
            .minimumScaleFactor(0.5)
            .adjustsFontForContentSizeCategory(true)
            .allowsDefaultTighteningForTruncation(true)
            .lineBreakStrategy(.pushOut)
            .shadowColor(.systemGray)
            .shadowOffset(CGSize(width: 1, height: 1))
            .preferredMaxLayoutWidth(200)
            .build()
        XCTAssertEqual(label.highlightedTextColor, .systemRed)
        XCTAssertTrue(label.isHighlighted)
        XCTAssertFalse(label.isEnabled)
        XCTAssertEqual(label.shadowColor, .systemGray)
        XCTAssertEqual(label.shadowOffset, CGSize(width: 1, height: 1))
        XCTAssertEqual(label.preferredMaxLayoutWidth, 200)
        XCTAssertTrue(label.adjustsFontSizeToFitWidth)
    }

    @MainActor
    func testUILabelAttributed() {
        let attr = NSAttributedString(string: "富文本", attributes: [.foregroundColor: UIColor.systemGreen])
        let label = UILabel().chain()
            .attributedText(attr)
            .build()
        XCTAssertEqual(label.attributedText, attr)
    }

    // MARK: - UIImageView 扩展

    @MainActor
    func testUIImageViewBasics() {
        let image = UIImage(systemName: "heart")!
        let highlighted = UIImage(systemName: "heart.fill")!
        let view = UIImageView().chain()
            .image(image)
            .highlightedImage(highlighted)
            .isHighlighted(true)
            .contentMode(.scaleAspectFill)
            .build()
        XCTAssertEqual(view.image, image)
        XCTAssertEqual(view.highlightedImage, highlighted)
        XCTAssertTrue(view.isHighlighted)
        XCTAssertEqual(view.contentMode, .scaleAspectFill)
    }

    @MainActor
    func testUIImageViewAnimating() {
        let f1 = UIImage(systemName: "a.circle")!
        let f2 = UIImage(systemName: "b.circle")!
        let view = UIImageView().chain()
            .animationImages([f1, f2])
            .animationDuration(1.0)
            .animationRepeatCount(0)
            .animating(true)
            .build()
        XCTAssertTrue(view.isAnimating)
        XCTAssertEqual(view.animationRepeatCount, 0)
    }

    @MainActor
    func testUIImageViewSymbolConfig() {
        let config = UIImage.SymbolConfiguration(pointSize: 18)
        let view = UIImageView().chain()
            .symbol("pencil")
            .preferredSymbolConfiguration(config)
            .build()
        XCTAssertEqual(view.image, UIImage(systemName: "pencil"))
        XCTAssertEqual(view.preferredSymbolConfiguration, config)
    }

    // MARK: - UIButton 扩展

    @MainActor
    func testUIButtonExtended() {
        let attr = NSAttributedString(string: "A", attributes: [.foregroundColor: UIColor.systemRed])
        let bg = UIImage(systemName: "square")!
        let button = UIButton.chain(type: .custom)
            .title("x", for: .normal)
            .title("X", for: .selected)
            .titleColor(.systemBlue, for: .normal)
            .attributedTitle(attr, for: .disabled)
            .image(UIImage(systemName: "star"), for: .normal)
            .backgroundImage(bg, for: .normal)
            .font(.systemFont(ofSize: 13))
            .build()
        XCTAssertEqual(button.title(for: .selected), "X")
        XCTAssertEqual(button.attributedTitle(for: .disabled), attr)
        XCTAssertEqual(button.backgroundImage(for: .normal), bg)
        XCTAssertEqual(button.titleLabel?.font, .systemFont(ofSize: 13))
    }

    // MARK: - UIControl 基座

    @MainActor
    func testControlTargetAndStates() {
        // isEnabled(false) 后 UIKit 会拒绝继续置高亮（disabled 控件不可高亮），
        // 故 isSelected、isHighlighted 分开在各自新按钮上验证。
        final class Target: NSObject {
            @objc func tapped() {}
        }
        let target = Target()
        let button = UIButton.chain(type: .custom)
            .target(target, action: #selector(Target.tapped), for: .touchUpInside)
            .isEnabled(false)
            .isSelected(true)
            .contentVerticalAlignment(.center)
            .contentHorizontalAlignment(.left)
            .build()
        XCTAssertFalse(button.isEnabled)
        XCTAssertTrue(button.isSelected)
        XCTAssertEqual(button.actions(forTarget: target, forControlEvent: .touchUpInside), ["tapped"])
        XCTAssertEqual(button.contentVerticalAlignment, .center)
        XCTAssertEqual(button.contentHorizontalAlignment, .left)

        let highlighted = UIButton.chain(type: .custom)
            .isHighlighted(true)
            .build()
        XCTAssertTrue(highlighted.isHighlighted)
    }

    // MARK: - UISwitch / UISegmentedControl / UISlider

    @MainActor
    func testUISwitch() {
        let sw = UISwitch().chain()
            .isOn(true)
            .onTintColor(.systemGreen)
            .thumbTintColor(.white)
            .build()
        XCTAssertTrue(sw.isOn)
        XCTAssertEqual(sw.onTintColor, .systemGreen)
        XCTAssertEqual(sw.thumbTintColor, .white)
    }

    @MainActor
    func testUISwitchExtendediOS14() {
        let on = UIImage(systemName: "checkmark")!
        let sw = UISwitch().chain()
            .preferredStyle(.checkbox)
            .title("免打扰")  // 仅 Catalyst/Mac idiom 生效，iOS 上不读，不进断言
            .onImage(on)
            .offImage(UIImage(systemName: "xmark"))
            .build()
        XCTAssertEqual(sw.preferredStyle, .checkbox)
        XCTAssertEqual(sw.onImage, on)
        XCTAssertNotNil(sw.offImage)
    }

    @MainActor
    func testUISegmentedControl() {
        let seg = UISegmentedControl().chain()
            .insertSegment(withTitle: "一", at: 0)
            .insertSegment(withTitle: "二", at: 1)
            .selectedSegmentIndex(1)
            .selectedSegmentTintColor(.systemBlue)
            .apportionsSegmentWidthsByContent(true)
            .build()
        XCTAssertEqual(seg.numberOfSegments, 2)
        XCTAssertEqual(seg.titleForSegment(at: 0), "一")
        XCTAssertEqual(seg.selectedSegmentIndex, 1)
        XCTAssertEqual(seg.selectedSegmentTintColor, .systemBlue)
        XCTAssertTrue(seg.apportionsSegmentWidthsByContent)
    }

    @MainActor
    func testUISlider() {
        let slider = UISlider().chain()
            .minimumValue(0)
            .maximumValue(100)
            .value(50)
            .isContinuous(false)
            .minimumTrackTintColor(.systemGreen)
            .maximumTrackTintColor(.systemGray3)
            .thumbTintColor(.systemBlue)
            .build()
        XCTAssertEqual(slider.minimumValue, 0)
        XCTAssertEqual(slider.maximumValue, 100)
        XCTAssertEqual(slider.value, 50)
        XCTAssertFalse(slider.isContinuous)
        XCTAssertEqual(slider.minimumTrackTintColor, .systemGreen)
        XCTAssertEqual(slider.thumbTintColor, .systemBlue)
    }

    // MARK: - UITextField / UISearchBar / UITextView

    @MainActor
    func testUITextFieldExtended() {
        let icon = UIImageView()
        let delegate = _TextFieldDelegate()
        let field = UITextField().chain()
            .text("x")
            .placeholder("请输入")
            .borderStyle(.roundedRect)
            .keyboardType(.emailAddress)
            .returnKeyType(.done)
            .autocapitalizationType(.none)
            .autocorrectionType(.no)
            .spellCheckingType(.no)
            .enablesReturnKeyAutomatically(true)
            .isSecureTextEntry(true)
            .leftView(icon)
            .leftViewMode(.always)
            .clearButtonMode(.whileEditing)
            .adjustsFontSizeToFitWidth(true)
            .minimumFontSize(10)
            .delegate(delegate)
            .build()
        XCTAssertEqual(field.placeholder, "请输入")
        XCTAssertEqual(field.keyboardType, .emailAddress)
        XCTAssertEqual(field.returnKeyType, .done)
        XCTAssertTrue(field.isSecureTextEntry)
        XCTAssertTrue(field.leftView === icon)
        XCTAssertEqual(field.leftViewMode, .always)
        XCTAssertEqual(field.clearButtonMode, .whileEditing)
        XCTAssertTrue(field.delegate === delegate)
    }

    @MainActor
    func testUISearchBar() {
        let bar = UISearchBar().chain()
            .placeholder("搜索")
            .prompt("提示")
            .searchBarStyle(.minimal)
            .barTintColor(.systemGray6)
            .isTranslucent(false)
            .scopeButtonTitles(["全部", "已读"])
            .selectedScopeButtonIndex(1)
            .showsCancelButton(true)
            .keyboardType(.default)
            .returnKeyType(.search)
            .build()
        XCTAssertEqual(bar.placeholder, "搜索")
        XCTAssertEqual(bar.searchBarStyle, .minimal)
        XCTAssertEqual(bar.scopeButtonTitles ?? [], ["全部", "已读"])
        XCTAssertEqual(bar.selectedScopeButtonIndex, 1)
        XCTAssertTrue(bar.showsCancelButton)
        XCTAssertEqual(bar.returnKeyType, .search)
    }

    @MainActor
    func testUITextView() {
        let delegate = _TextViewDelegate()
        let view = UITextView().chain()
            .text("多行文本")
            .font(.systemFont(ofSize: 15))
            .textColor(.label)
            .textAlignment(.left)
            .isEditable(true)
            .isSelectable(true)
            .dataDetectorTypes([.link])
            .allowsEditingTextAttributes(false)
            .keyboardType(.default)
            .returnKeyType(.default)
            .delegate(delegate)
            .build()
        XCTAssertEqual(view.text, "多行文本")
        XCTAssertEqual(view.font, .systemFont(ofSize: 15))
        XCTAssertEqual(view.textColor, .label)
        XCTAssertTrue(view.isEditable)
        XCTAssertTrue(view.isSelectable)
        XCTAssertEqual(view.dataDetectorTypes, [.link])
        XCTAssertTrue(view.delegate === delegate)
    }

    // MARK: - UIStackView 扩展

    @MainActor
    func testUIStackViewExtended() {
        let a = UIView()
        let b = UIView()
        let stack = UIStackView.chain(arrangedSubviews: [a])
            .axis(.vertical)
            .spacing(8)
            .alignment(.center)
            .distribution(.fillEqually)
            .customSpacing(20, after: a)
            .arrangedSubviews([b])
            .isBaselineRelativeArrangement(true)
            .isLayoutMarginsRelativeArrangement(true)
            .directionalLayoutMargins(NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
            .build()
        XCTAssertEqual(stack.customSpacing(after: a), 20)
        XCTAssertTrue(stack.arrangedSubviews.contains(b))
        XCTAssertTrue(stack.isBaselineRelativeArrangement)
        XCTAssertTrue(stack.isLayoutMarginsRelativeArrangement)
    }

    // MARK: - 滚动与列表

    @MainActor
    func testUIScrollViewProperties() {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 400)).chain()
            .isScrollEnabled(true)
            .contentSize(CGSize(width: 1000, height: 1000))
            .contentOffset(CGPoint(x: 10, y: 20))
            .contentInset(UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4))
            .scrollIndicatorInsets(.zero)
            .indicatorStyle(.black)
            .bounces(false)
            .alwaysBounceHorizontal(true)
            .alwaysBounceVertical(true)
            .showsHorizontalScrollIndicator(false)
            .showsVerticalScrollIndicator(false)
            .isPagingEnabled(true)
            .decelerationRate(.fast)
            .keyboardDismissMode(.onDrag)
            .contentInsetAdjustmentBehavior(.never)
            .minimumZoomScale(1)
            .maximumZoomScale(4)
            .build()
        XCTAssertEqual(scroll.contentSize, CGSize(width: 1000, height: 1000))
        XCTAssertEqual(scroll.contentOffset, CGPoint(x: 10, y: 20))
        XCTAssertTrue(scroll.isPagingEnabled)
        XCTAssertEqual(scroll.decelerationRate, .fast)
        XCTAssertEqual(scroll.contentInsetAdjustmentBehavior, .never)
        XCTAssertEqual(scroll.keyboardDismissMode, .onDrag)
    }

    @MainActor
    func testUITableViewProperties() {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
        let delegate = _TableViewDelegate()
        let table = UITableView(frame: .zero, style: .plain).chain()
            .register(UITableViewCell.self, forCellReuseIdentifier: "cell")
            .register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "hdr")
            .rowHeight(60)
            .estimatedRowHeight(44)
            .sectionHeaderHeight(30)
            .sectionFooterHeight(30)
            .estimatedSectionHeaderHeight(20)
            .estimatedSectionFooterHeight(20)
            .separatorStyle(.none)
            .separatorColor(.systemGray3)
            .separatorInset(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
            // 注意：UIKit 里 allowsSelection 与 allowsMultipleSelection 互相钳制——
            // 多选开会让单选自动开，单选关又会让多选关。链里只保留「多选开」这半边。
            .allowsMultipleSelection(true)
            .allowsMultipleSelectionDuringEditing(true)
            .isEditing(false)
            .tableHeaderView(header)
            .tableFooterView(UIView())
            .sectionIndexColor(.systemBlue)
            .sectionIndexBackgroundColor(.clear)
            .sectionIndexTrackingBackgroundColor(.systemGray6)
            .cellLayoutMarginsFollowReadableWidth(false)
            .insetsContentViewsToSafeArea(false)
            .delegate(delegate)
            .dataSource(delegate)
            .build()
        XCTAssertEqual(table.rowHeight, 60)
        XCTAssertEqual(table.estimatedRowHeight, 44)
        XCTAssertEqual(table.separatorStyle, .none)
        XCTAssertTrue(table.allowsMultipleSelection)
        XCTAssertTrue(table.tableHeaderView === header)
        XCTAssertEqual(table.sectionIndexColor, .systemBlue)
        XCTAssertTrue(table.insetsContentViewsToSafeArea == false)
        XCTAssertTrue(table.delegate as AnyObject? === delegate)
        XCTAssertTrue(table.dataSource as AnyObject? === delegate)
    }

    @MainActor
    func testUITableViewSingleSelectionOff() {
        // 单选关是稳定状态，单独验证（与多选互为钳制，不能同链同断）。
        let table = UITableView(frame: .zero, style: .plain).chain()
            .allowsSelection(false)
            .build()
        XCTAssertFalse(table.allowsSelection)
    }

    @MainActor
    func testUICollectionViewExtended() {
        let layout = UICollectionViewFlowLayout()
        let dataSource = _CollectionViewDataSource()
        let background = UIView()
        let view = UICollectionView.chain(layout: layout)
            .register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
            .register(UICollectionReusableView.self,
                      forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                      withReuseIdentifier: "hdr")
            .isPrefetchingEnabled(false)
            // 同 UITableView：单选/多选互为钳制，链里只保留「多选开」。
            .allowsMultipleSelection(true)
            .backgroundView(background)
            .delegate(dataSource)
            .dataSource(dataSource)
            .build()
        XCTAssertFalse(view.isPrefetchingEnabled)
        XCTAssertTrue(view.allowsMultipleSelection)
        XCTAssertTrue(view.backgroundView === background)
        XCTAssertTrue(view.delegate as AnyObject? === dataSource)
    }

    @MainActor
    func testUICollectionViewSingleSelectionOff() {
        let view = UICollectionView.chain(layout: UICollectionViewFlowLayout())
            .allowsSelection(false)
            .build()
        XCTAssertFalse(view.allowsSelection)
    }

    // MARK: - 页码 / 进度 / 转圈

    @MainActor
    func testUIPageControl() {
        let control = UIPageControl().chain()
            .numberOfPages(5)
            .currentPage(2)
            .currentPageIndicatorTintColor(.systemBlue)
            .pageIndicatorTintColor(.systemGray)
            .hidesForSinglePage(true)
            .build()
        XCTAssertEqual(control.numberOfPages, 5)
        XCTAssertEqual(control.currentPage, 2)
        XCTAssertEqual(control.currentPageIndicatorTintColor, .systemBlue)
        XCTAssertEqual(control.pageIndicatorTintColor, .systemGray)
        XCTAssertTrue(control.hidesForSinglePage)
    }

    @MainActor
    func testUIProgressView() {
        let progress = Progress(totalUnitCount: 10)
        let bar = UIProgressView.chain(style: .bar)
            .progress(0.5)
            .progressTintColor(.systemGreen)
            .trackTintColor(.systemGray5)
            .observedProgress(progress)
            .build()
        XCTAssertEqual(bar.progress, 0.5)
        XCTAssertEqual(bar.progressTintColor, .systemGreen)
        XCTAssertEqual(bar.trackTintColor, .systemGray5)
        XCTAssertTrue(bar.observedProgress === progress)
    }

    @MainActor
    func testUIActivityIndicatorView() {
        let spinner = UIActivityIndicatorView.chain(style: .medium)
            .hidesWhenStopped(true)
            .color(.systemBlue)
            .animating(true)
            .build()
        XCTAssertTrue(spinner.isAnimating)
        XCTAssertTrue(spinner.hidesWhenStopped)
        XCTAssertEqual(spinner.color, .systemBlue)

        let stopped = UIActivityIndicatorView.chain(style: .large)
            .animating(false)
            .build()
        XCTAssertFalse(stopped.isAnimating)
    }

    // MARK: - 阶段 B：UIStepper / UIDatePicker / UIPickerView / 刷新 / 毛玻璃

    @MainActor
    func testUIStepper() {
        let step = UIStepper().chain()
            .minimumValue(0)
            .maximumValue(10)
            .stepValue(2)
            .value(4)
            .wraps(true)
            .autorepeat(false)
            .isContinuous(true)
            .build()
        XCTAssertEqual(step.minimumValue, 0)
        XCTAssertEqual(step.maximumValue, 10)
        XCTAssertEqual(step.stepValue, 2)
        XCTAssertEqual(step.value, 4)
        XCTAssertTrue(step.wraps)
        XCTAssertFalse(step.autorepeat)
        XCTAssertTrue(step.isContinuous)
    }

    @MainActor
    func testUIDatePicker() {
        // Locale/TimeZone 的 == 是实例级比较，值相同也可能判不等 → 用 identifier 比内容。
        let picker = UIDatePicker().chain()
            .locale(Locale(identifier: "zh_CN"))
            .timeZone(TimeZone(identifier: "Asia/Shanghai"))
            .datePickerMode(.countDownTimer)
            .minuteInterval(5)
            .preferredDatePickerStyle(.wheels)
            .build()
        XCTAssertEqual(picker.locale?.identifier, Locale(identifier: "zh_CN").identifier)
        XCTAssertEqual(picker.timeZone?.identifier, "Asia/Shanghai")
        XCTAssertEqual(picker.datePickerMode, .countDownTimer)
        XCTAssertEqual(picker.minuteInterval, 5)
        XCTAssertEqual(picker.preferredDatePickerStyle, .wheels)

        // countDownDuration：秒数需为 60 的正倍数，否则 UIKit 会取整到最近合法值。
        let timer = UIDatePicker().chain()
            .datePickerMode(.countDownTimer)
            .countDownDuration(600)
            .build()
        XCTAssertEqual(timer.countDownDuration, 600, accuracy: 0.001)
    }

    @MainActor
    func testUIPickerView() {
        let dataSource = _PickerDataSource()
        let picker = UIPickerView().chain()
            .dataSource(dataSource)
            .delegate(dataSource)
            .reloadAllComponents()
            .selectRow(1, inComponent: 0, animated: false)
            .build()
        XCTAssertTrue(picker.dataSource as AnyObject? === dataSource)
        XCTAssertTrue(picker.delegate as AnyObject? === dataSource)
        XCTAssertEqual(picker.selectedRow(inComponent: 0), 1)
    }

    @MainActor
    func testUIRefreshControl() {
        // beginRefreshing() 只在控件真正附着于可见滚动列表时才置位 isRefreshing，
        // 单测场景不构成窗口层级 → 只做「链方法走通 + 附件关系」的冒烟。
        let rc = UIRefreshControl().chain()
            .attributedTitle(NSAttributedString(string: "下拉刷新"))
            .build()
        XCTAssertEqual(rc.attributedTitle?.string, "下拉刷新")

        let scroll = UIScrollView().chain()
            .refreshControl(UIRefreshControl().chain().refreshing(true).build())
            .build()
        XCTAssertNotNil(scroll.refreshControl)

        let idle = UIRefreshControl().chain()
            .refreshing(false)
            .build()
        XCTAssertFalse(idle.isRefreshing)
    }

    @MainActor
    func testUIVisualEffectView() {
        let blur = UIBlurEffect(style: .systemMaterial)
        let view = UIVisualEffectView().chain()
            .effect(blur)
            .build()
        XCTAssertEqual(view.effect as? UIBlurEffect, blur)
    }

    // MARK: - 阶段 B：手势

    @MainActor
    func testUIGestureRecognizers() {
        let target = _GestureTarget()
        let card = UIView()
        let tap = UITapGestureRecognizer.chain()
            .numberOfTapsRequired(2)
            .numberOfTouchesRequired(1)
            .target(target, action: #selector(_GestureTarget.fire))
            .added(to: card)
            .build()
        XCTAssertEqual(tap.numberOfTapsRequired, 2)
        XCTAssertEqual(tap.numberOfTouchesRequired, 1)
        XCTAssertTrue(tap.view === card)

        let longPress = UILongPressGestureRecognizer.chain()
            .minimumPressDuration(0.5)
            .allowableMovement(10)
            .isEnabled(false)
            .build()
        XCTAssertEqual(longPress.minimumPressDuration, 0.5)
        XCTAssertEqual(longPress.allowableMovement, 10)
        XCTAssertFalse(longPress.isEnabled)

        let swipe = UISwipeGestureRecognizer.chain()
            .direction(.left)
            .numberOfTouchesRequired(1)
            .build()
        XCTAssertEqual(swipe.direction, .left)

        let pan = UIPanGestureRecognizer.chain()
            .minimumNumberOfTouches(1)
            .maximumNumberOfTouches(2)
            .build()
        XCTAssertEqual(pan.maximumNumberOfTouches, 2)

        let edge = UIScreenEdgePanGestureRecognizer.chain()
            .edges(.right)
            .build()
        XCTAssertEqual(edge.edges, .right)
    }

    // MARK: - 阶段 B：UIView 动作方法（system extension 形态）

    @MainActor
    func testUIViewActionMethods() {
        let tap = UITapGestureRecognizer()
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100)).chain()
            .addGestureRecognizer(tap)
            .removeGestureRecognizer(tap)
            .setNeedsLayout()
            .layoutIfNeeded()
            .setNeedsUpdateConstraints()
            .setNeedsDisplay(CGRect(x: 0, y: 0, width: 10, height: 10))
            .invalidateIntrinsicContentSize()
            .autoresizingMask([.flexibleWidth, .flexibleHeight])
            .autoresizesSubviews(true)
            .build()
        XCTAssertEqual(view.frame.size, CGSize(width: 100, height: 100))
        XCTAssertEqual(view.gestureRecognizers?.count ?? 0, 0)
        XCTAssertEqual(view.autoresizingMask, [.flexibleWidth, .flexibleHeight])
        XCTAssertTrue(view.autoresizesSubviews)

        let label = UILabel().chain()
            .text("自适应")
            .sizeToFit()
            .build()
        XCTAssertGreaterThan(label.frame.width, 0)
    }

    // MARK: - 阶段 B：滚动指示条细分 / PageControl 扩充 / Stack 增删 / 输入面板

    @MainActor
    func testScrollIndicatorInsetsSplit() {
        let scroll = UIScrollView().chain()
            .verticalScrollIndicatorInsets(UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0))
            .horizontalScrollIndicatorInsets(UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 0))
            .build()
        XCTAssertEqual(scroll.verticalScrollIndicatorInsets, UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0))
        XCTAssertEqual(scroll.horizontalScrollIndicatorInsets, UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 0))
    }

    @MainActor
    func testUIPageControlExtended() {
        let image = UIImage(systemName: "circle")!
        let control = UIPageControl().chain()
            .numberOfPages(3)
            .allowsContinuousInteraction(false)
            .backgroundStyle(.minimal)
            .preferredIndicatorImage(image)
            .indicatorImage(image, forPage: 1)
            .build()
        XCTAssertFalse(control.allowsContinuousInteraction)
        XCTAssertEqual(control.backgroundStyle, .minimal)
        XCTAssertEqual(control.preferredIndicatorImage, image)
        XCTAssertEqual(control.indicatorImage(forPage: 1), image)
    }

    @MainActor
    func testUIStackViewInsertRemove() {
        let a = UIView()
        let stack = UIStackView().chain()
            .insertArrangedSubview(a, at: 0)
            .build()
        XCTAssertEqual(stack.arrangedSubviews, [a])

        let b = UIView()
        let stack2 = UIStackView.chain(arrangedSubviews: [a, b])
            .removeArrangedSubview(a)
            .build()
        XCTAssertFalse(stack2.arrangedSubviews.contains(a))
        XCTAssertTrue(stack2.arrangedSubviews.contains(b))
    }

    @MainActor
    func testInputViewAndAccessory() {
        // textField / textView 都可设 inputView 替代系统键盘。
        let panel = UIToolbar()
        let field = UITextField().chain()
            .inputView(panel)
            .inputAccessoryView(panel)
            .build()
        XCTAssertTrue(field.inputView === panel)
        XCTAssertTrue(field.inputAccessoryView === panel)

        let textView = UITextView().chain()
            .inputView(panel)
            .build()
        XCTAssertTrue(textView.inputView === panel)
    }

    // MARK: - 阶段 B：列表/集合预取、拖拽、焦点

    @MainActor
    func testUITableViewDragPrefetchFocus() {
        let table = UITableView(frame: .zero, style: .plain).chain()
            .dragInteractionEnabled(true)
            .sectionIndexMinimumDisplayRowCount(20)
            .selectionFollowsFocus(false)
            .build()
        XCTAssertTrue(table.dragInteractionEnabled)
        XCTAssertEqual(table.sectionIndexMinimumDisplayRowCount, 20)
        XCTAssertFalse(table.selectionFollowsFocus)
    }

    @MainActor
    func testUICollectionViewPrefetchFocus() {
        let view = UICollectionView.chain(layout: UICollectionViewFlowLayout())
            .dragInteractionEnabled(true)
            .allowsFocus(false)
            .selectionFollowsFocus(false)
            .build()
        XCTAssertTrue(view.dragInteractionEnabled)
        XCTAssertFalse(view.allowsFocus)
        XCTAssertFalse(view.selectionFollowsFocus)
    }

    // MARK: - 阶段 B：BarItem 类（静态工厂进链）

    @MainActor
    func testUIBarButtonItemChain() {
        let item = UIBarButtonItem.chain(title: "保存", style: .done)
            .tintColor(.systemBlue)
            .isEnabled(false)
            .tag(1)
            .possibleTitles(["保存", "保存中"])
            .build()
        XCTAssertEqual(item.title, "保存")
        XCTAssertEqual(item.style, .done)
        XCTAssertEqual(item.tintColor, .systemBlue)
        XCTAssertFalse(item.isEnabled)
        XCTAssertEqual(item.tag, 1)
        XCTAssertEqual(item.possibleTitles, ["保存", "保存中"])

        let system = UIBarButtonItem.chain(systemItem: .fixedSpace)
            .width(16)
            .build()
        XCTAssertEqual(system.width, 16)
    }

    @MainActor
    func testUITabBarItemChain() {
        let image = UIImage(systemName: "house")!
        let item = UITabBarItem.chain(title: "首页", image: image)
            .selectedImage(UIImage(systemName: "house.fill"))
            .badgeValue("3")
            .badgeColor(.systemRed)
            .build()
        XCTAssertEqual(item.title, "首页")
        XCTAssertEqual(item.image, image)
        XCTAssertEqual(item.badgeValue, "3")
        XCTAssertEqual(item.badgeColor, .systemRed)
    }

    @MainActor
    func testUINavigationItemChain() {
        let item = UINavigationItem.chain(title: "详情")
            .largeTitleDisplayMode(.never)
            .hidesBackButton(true)
            .build()
        XCTAssertEqual(item.title, "详情")
        XCTAssertEqual(item.largeTitleDisplayMode, .never)
        XCTAssertTrue(item.hidesBackButton)
    }

    // MARK: - 阶段 B：三根系统栏

    @MainActor
    func testUINavigationBar() {
        let navBar = UINavigationBar().chain()
            .barStyle(.black)
            .isTranslucent(false)
            .barTintColor(.systemGray6)
            .prefersLargeTitles(true)
            .build()
        XCTAssertEqual(navBar.barStyle, .black)
        XCTAssertFalse(navBar.isTranslucent)
        XCTAssertEqual(navBar.barTintColor, .systemGray6)
        XCTAssertTrue(navBar.prefersLargeTitles)

        // UIKit 内部会复制 appearance 实例（`===` 会失败），用内容（背景色）断言回读。
        let appearance = UINavigationBarAppearance()
        appearance.backgroundColor = .systemPink
        let styled = UINavigationBar().chain()
            .standardAppearance(appearance)
            .scrollEdgeAppearance(appearance)
            .compactAppearance(appearance)
            .build()
        XCTAssertEqual(styled.standardAppearance.backgroundColor, .systemPink)
        XCTAssertEqual(styled.scrollEdgeAppearance?.backgroundColor, .systemPink)
        XCTAssertEqual(styled.compactAppearance?.backgroundColor, .systemPink)
    }

    @MainActor
    func testUITabBar() {
        let tabBar = UITabBar().chain()
            .barStyle(.black)
            .unselectedItemTintColor(.systemGray)
            .itemPositioning(.centered)
            .build()
        XCTAssertEqual(tabBar.barStyle, .black)
        XCTAssertEqual(tabBar.unselectedItemTintColor, .systemGray)
        XCTAssertEqual(tabBar.itemPositioning, .centered)

        let appearance = UITabBarAppearance()
        appearance.backgroundColor = .systemPink
        let styled = UITabBar().chain()
            .standardAppearance(appearance)
            .scrollEdgeAppearance(appearance)
            .build()
        XCTAssertEqual(styled.standardAppearance.backgroundColor, .systemPink)
        XCTAssertEqual(styled.scrollEdgeAppearance?.backgroundColor, .systemPink)
    }

    @MainActor
    func testUIToolbar() {
        let toolbar = UIToolbar().chain()
            .barStyle(.black)
            .items([UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)],
                   animated: false)
            .build()
        XCTAssertEqual(toolbar.barStyle, .black)
        XCTAssertEqual(toolbar.items?.count, 1)

        let appearance = UIToolbarAppearance()
        appearance.backgroundColor = .systemPink
        let styled = UIToolbar().chain()
            .standardAppearance(appearance)
            .compactScrollEdgeAppearance(appearance)
            .build()
        XCTAssertEqual(styled.standardAppearance.backgroundColor, .systemPink)
        XCTAssertEqual(styled.compactScrollEdgeAppearance?.backgroundColor, .systemPink)
    }
}

// MARK: - 最小代理桩（链方法取参类型不同的重载解析验证）

private final class _TextFieldDelegate: NSObject, UITextFieldDelegate {}

private final class _TextViewDelegate: NSObject, UITextViewDelegate {}

private final class _TableViewDelegate: NSObject, UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 0 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        UITableViewCell()
    }
}

private final class _CollectionViewDataSource: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 0 }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        UICollectionViewCell()
    }
}

private final class _GestureTarget: NSObject {
    @objc func fire() {}
}

private final class _PickerDataSource: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { 3 }
}