//
//  CarouselComponent.swift
//  SwiftBridgeComponents
//
//  轮播 banner —— 交互容器：横向分页 UIScrollView + 页码圆点 + 可选自动播放 + **无限轮播**。
//  吸收 Demo04 的滚动正解，并新增本包第一个「长寿命异步对象」：
//    · offset 上报去重：翻页按 page 取整，变了才上报，不每帧打风暴。
//    · 压制自发上报：程序化 setContentOffset（业务注入 / 自动播）前打标志位，
//      阻止 scrollViewDidScroll 再把自己引发的位置当用户意图上报。
//    · Timer 生命周期：自动播用 Timer；Timer 会 retain target，这里用一个只持
//      weak 的代理，拆桥时 teardown 必须 invalidate + 置 nil，否则空转。
//
//  ★ 无限轮播的正解（isInfinite = true 时）：
//    把 slides 渲染成 3N 页（三个拷贝：A[0,N) / B[N,2N) / C[2N,3N)），停在「中带 B」。
//      前进到 C 带开头（p >= 2N）→ 无动画瞬移回 B 带同页（p - N）；
//      后退到 A 带（p < N）     → 无动画瞬移去 C 带同页（p + 2N）。
//    瞬移前后页内容完全相同，肉眼无感；于是向前向后都永远滑不完。
//    上报/圆点都用「真实页 = 可视页 % N」，业务侧只看得见 0..N-1，感知不到拷贝。
//
//  差异映射字段清单（apply 里逐字段比较）：
//    slides / isInfinite → 重建页 + 归位中带 + 钳制 currentIndex
//    currentIndex        → 命令式滚动（就近拷贝，程序化，不反向上报）
//    autoPlayInterval    → 停/启定时器（nil = 不自动播）
//  页触碰 / 翻页只上报意图，展示状态本身已是「唯一真相」视图。
//

import UIKit
import SnapKit
import SwiftBridgeKit
import SwiftChainKit

// MARK: - 契约层

/// 一页数据。纯值模型（Hashable），刻意不带 UIImage：保住 Hashable / Sendable，
/// 要配图的场景由业务在最外层扩展（等价于给卡片的底色/文案上色）。
public struct CarouselSlide: Hashable {
    /// 页唯一标识：去重 / 稳定身份用。
    public var id: String
    /// 主标题，居中显示在卡片上。
    public var title: String
    /// 副标题；nil = 不显示。
    public var subtitle: String?
    /// 配色主题：卡片浅色底与文字色。
    public var tone: ComponentTone

    /// 构造一页数据。
    /// - Parameters:
    ///   - id: 页唯一标识。
    ///   - title: 主标题。
    ///   - subtitle: 副标题；默认 nil（无副标题）。
    ///   - tone: 配色主题；默认 .primary。
    public init(id: String,
                title: String,
                subtitle: String? = nil,
                tone: ComponentTone = .primary) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
    }
}

/// 轮播的展示状态：数据页 + 命令式翻页目标 + 自动播参数 + 无限轮播开关。
public struct CarouselState: BridgeState {
    /// 数据页（真实页）。无限轮播内部渲染 3N 份拷贝，业务始终只看这一份。
    public var slides: [CarouselSlide]
    /// 命令式翻页目标：业务想「跳到第 N 页」时改它，视图程序化滚过去。
    public var currentIndex: Int
    /// 自动播放间隔（秒）；nil = 不自动播。
    public var autoPlayInterval: Double?
    /// 无限轮播：首尾无缝衔接（默认开）。单页时天然退化为不循环。
    public var isInfinite: Bool

    /// 构造轮播状态。
    /// - Parameters:
    ///   - slides: 数据页（真实页）。
    ///   - currentIndex: 初始页 / 命令式翻页目标；默认 0。
    ///   - autoPlayInterval: 自动播放间隔（秒）；默认 nil（不自动播）。
    ///   - isInfinite: 是否无限轮播；默认 true。
    public init(slides: [CarouselSlide],
                currentIndex: Int = 0,
                autoPlayInterval: Double? = nil,
                isInfinite: Bool = true) {
        self.slides = slides
        self.currentIndex = currentIndex
        self.autoPlayInterval = autoPlayInterval
        self.isInfinite = isInfinite
    }
}

/// 轮播交互意图：翻页（真实页）与点击某一页。
public enum CarouselIntent: BridgeIntent {
    /// 翻到第 n 页（n 为真实页 0..<N，拷贝对业务不可见）。
    case pageChanged(Int)
    /// 点击了某一页，携带该页数据。
    case tapped(CarouselSlide)
}

// MARK: - 无限循环的纯计算（internal，供视图用 + @testable 单测）

/// 视图不直接算「可视页 ⇄ 真实页」，统一走这里的纯函数：
/// 不收编状态、不依赖 UIKit，无限循环的核心数学单测就能覆盖。
internal enum CarouselGeometry {

    /// 渲染页数：无限 = 3N（A/B/C 三份拷贝），有限 = N。
    static func renderedCount(realCount: Int, isInfinite: Bool) -> Int {
        (isInfinite && realCount >= 2) ? realCount * 3 : realCount
    }

    /// 中带基数：可视页停在 [base, base+N)，保证前后都有伸展空间。
    static func visualBase(realCount: Int, isInfinite: Bool) -> Int {
        (isInfinite && realCount >= 2) ? realCount : 0
    }

    /// 把可视页收进中带（同 slide 的无动画瞬移目标）：
    ///   p >= 2N  → p - N（前进到 C 带开头，回 B 带同页）
    ///   p <  N   → p + 2N（后退进 A 带，去 C 带同页）
    static func normalize(_ p: Int, realCount: Int, isInfinite: Bool) -> Int {
        guard isInfinite, realCount >= 2, renderedCount(realCount: realCount, isInfinite: true) > 0 else { return p }
        let total = renderedCount(realCount: realCount, isInfinite: true)
        var q = min(max(p, 0), total - 1)
        if q >= 2 * realCount {
            q -= realCount
        } else if q < realCount {
            q += 2 * realCount
        }
        return q
    }

    /// 真实的「当前播放页」通常要求在时间轴中点附近才能向前走：
    /// 自动播统一先收进中带 [N, 2N)（A 带 → +N、C 带 → -N，都是同页瞬移）。
    static func middle(_ p: Int, realCount: Int, isInfinite: Bool) -> Int {
        guard isInfinite, realCount >= 2 else { return p }
        if p >= 2 * realCount { return p - realCount }
        if p < realCount { return p + realCount }
        return p
    }

    /// 真实页 → 距离当前可视页最近的那份拷贝（避免长距离回卷）。
    static func nearest(_ p: Int, realCount: Int, from current: Int, isInfinite: Bool) -> Int {
        guard isInfinite, realCount >= 2 else { return p }
        let total = renderedCount(realCount: realCount, isInfinite: true)
        return [p, realCount + p, 2 * realCount + p]
            .filter { $0 >= 0 && $0 < total }
            .min { abs($0 - current) < abs($1 - current) }
            ?? (realCount + p)
    }
}

// MARK: - 桥视图

/// 轮播 banner 桥视图：横向分页 UIScrollView + 页码圆点 + 可选自动播放 + **无限轮播**。
@MainActor
public final class CarouselBridgeView: UIView, BridgeView {

    /// 桥状态类型：数据页 / 翻页目标 / 自动播 / 无限轮播。
    public typealias State = CarouselState
    /// 桥意图类型：翻页与点击的上报。
    public typealias Intent = CarouselIntent

    /// 意图上抛回调：翻页（去重后的真实页）与点击某页。
    public var onIntent: ((CarouselIntent) -> Void)?

    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()

    /// 每桥主题覆盖（运行时换肤）；`resolvedTheme()` = 本属性 ?? 全局 current。
    public var theme: (any BridgeTheme)?
    /// 最近一次生效的主题缓存：主题变化时强制重建页面（页面在 apply 之外 makePage 生成）。
    private var cachedTheme: ComponentTheme?

    /// 原始 slides（真实页），长度 N。
    private var slides: [CarouselSlide] = []
    /// 渲染页 = slides 的三份拷贝（无限模式），或 slides 本体（有限模式）。长度 renderCount。
    private var renderedSlides: [CarouselSlide] = []
    /// internal（非 private）：留给 @testable 测试校验页面数用。
    var pageViews: [UIView] = []
    private var isInfinite = false

    /// 当前所在的「可视页」（渲染空间 0..<renderCount）。逻辑状态的中枢。
    private var currentVisual: Int = 0
    /// 业务侧已应用的 currentIndex（真实页水印），用于「命令式滚动」差分。
    private var lastAppliedIndex: Int = -1
    /// 已上报过的「真实页」，去重用。
    private var lastReportedReal: Int = -1
    /// 压制「程序化滚动引发的自发上报」（吸收 Demo04）。
    /// 动画式程序化滚动期间保持 true，由开始拖动 / 动画结束清掉。
    private var isProgrammaticScroll = false

    private var timer: Timer?
    private var autoPlayInterval: Double?

    /// 构造组件：搭好分页 ScrollView、页码圆点与各自约束。
    /// - Parameters:
    ///   - frame: 初始 frame。
    override public init(frame: CGRect) {
        super.init(frame: frame)

        // 分页滚动容器：整页翻 + 隐藏横向指示条 + 禁回弹；尺寸由下方 SnapKit 布局
        scrollView.chain()
            .isPagingEnabled(true)
            .showsHorizontalScrollIndicator(false)
            .bounces(false)
            .delegate(self)
            .added(to: self)

        pageControl.chain()
            .hidesForSinglePage(true)
            .pageIndicatorTintColor(.systemGray4)
            .added(to: self)

        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(pageControl.snp.top)
        }

        pageControl.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(ComponentMetrics.carouselDotHeight())
        }
    }

    /// 不可用：组件只通过代码构造（不支持 NIB / 解档）。
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 固有内容尺寸：宽不固定（noIntrinsicMetric），高 = banner 高 + 圆点高。
    override public var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric,
               height: ComponentMetrics.carouselBannerHeight() + ComponentMetrics.carouselDotHeight())
    }

    // MARK: - 布局

    /// 布局：按页宽摆放每页并维护 contentSize；宽度变化时把 offset 回正到当前可视页。
    override public func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        guard width > 0 else { return }

        let pageSize = scrollView.bounds.size
        scrollView.contentSize = CGSize(width: width * CGFloat(renderedSlides.count), height: pageSize.height)
        for (index, page) in pageViews.enumerated() {
            page.frame = CGRect(x: CGFloat(index) * width, y: 0, width: width, height: pageSize.height)
        }

        // 内容尺寸两侧变化会让 offset 相对失真 → 按当前可视页回正
        if !renderedSlides.isEmpty {
            let x = CGFloat(currentVisual) * width
            if abs(scrollView.contentOffset.x - x) > 0.5 {
                scrollView.contentOffset = CGPoint(x: x, y: 0)
                isProgrammaticScroll = false
            }
        }
    }

    // MARK: - BridgeView

    /// 应用最新状态：slides / isInfinite 变化重建页并归位中带；
    /// 仅 currentIndex 变化做就近拷贝的命令式滚动；autoPlayInterval 变化重建定时器。
    /// - Parameters:
    ///   - state: 最新的轮播状态。
    public func apply(_ state: CarouselState) {
        // 主题解析：每桥 override → 全局 current；变化即 themeChanged（页面颜色强制重绘）
        let theme = resolvedTheme()
        let themeChanged = (cachedTheme != theme)
        cachedTheme = theme

        // 页面在 apply 之外生成（rebuildPages → makePage），主题变了不重建就不会重画颜色；
        // 把 themeChanged 并入重建条件，换肤必走 makePage 重新 resolvedTheme()。
        if state.slides != slides || state.isInfinite != isInfinite || themeChanged {
            isInfinite = state.isInfinite
            rebuildPages(with: state.slides)
        }

        // 命令式翻页：只执行「新命令」，且不反向上报（下行不是用户意图）。
        let realCount = slides.count
        if realCount > 0 {
            let clamped = min(max(state.currentIndex, 0), realCount - 1)
            if clamped != lastAppliedIndex {
                lastAppliedIndex = clamped
                let target = CarouselGeometry.nearest(clamped,
                                                     realCount: realCount,
                                                     from: currentVisual,
                                                     isInfinite: isInfinite)
                programmaticScroll(to: target, animated: false)
            }
        }

        if state.autoPlayInterval != autoPlayInterval {
            updateTimer(state.autoPlayInterval)
        }
    }

    /// 拆桥：先 invalidate + 置 nil 定时器（长寿命异步对象），再断 delegate 与意图回调。
    public func teardown() {
        // 先停定时器（长寿命异步对象），再断 delegate
        timer?.invalidate()
        timer = nil
        scrollView.delegate = nil
        onIntent = nil
    }

    // MARK: - 页重建 / 无限循环的搬运

    private var realCount: Int { slides.count }

    private func rebuildPages(with slides: [CarouselSlide]) {
        pageViews.forEach { $0.removeFromSuperview() }
        pageViews.removeAll()
        self.slides = slides

        // 渲染 N / 3N 页
        let rendered = CarouselGeometry.renderedCount(realCount: slides.count, isInfinite: isInfinite)
        if rendered > slides.count {
            // 无限：把 N 张 slides 复制出 A/B/C 三份
            renderedSlides = (0..<3).flatMap { _ in slides }
        } else {
            renderedSlides = slides
        }
        pageControl.numberOfPages = slides.count

        // 归位到「当前真实页」的中带基数：保证前后都有无限伸展空间
        if slides.isEmpty {
            currentVisual = 0
            lastAppliedIndex = -1
            lastReportedReal = -1
            pageControl.currentPage = 0
        } else {
            let base = CarouselGeometry.visualBase(realCount: slides.count, isInfinite: isInfinite)
            let real = lastAppliedIndex >= 0 ? min(lastAppliedIndex, slides.count - 1) : 0
            currentVisual = base + real
            lastAppliedIndex = real
            pageControl.currentPage = real
        }

        for (index, slide) in renderedSlides.enumerated() {
            let page = makePage(for: slide)
            page.tag = index
            let tap = UITapGestureRecognizer(target: self, action: #selector(handlePageTap(_:)))
            page.addGestureRecognizer(tap)
            scrollView.addSubview(page)
            pageViews.append(page)
        }

        // 直接回正（比等 layoutSubviews 更即时；宽度未知时交给 layoutSubviews）
        if scrollView.bounds.width > 0, !renderedSlides.isEmpty {
            scrollView.contentOffset = CGPoint(x: CGFloat(currentVisual) * scrollView.bounds.width, y: 0)
        }
        setNeedsLayout()
    }

    /// 把可视页收进中带 B[realCount, 2*realCount)：越过 B 就瞬移到同页拷贝，肉眼无感。
    private func normalizeVisualPosition() {
        guard isInfinite, realCount >= 2, !renderedSlides.isEmpty else { return }
        let normalized = CarouselGeometry.normalize(currentVisual, realCount: realCount, isInfinite: true)
        if normalized != currentVisual {
            teleport(to: normalized)
        }
    }

    /// 无动画瞬移：同页拷贝跳转，不上报（真实页没变）。
    private func teleport(to index: Int) {
        let width = max(scrollView.bounds.width, 1)
        guard index >= 0, index < renderedSlides.count else { return }
        isProgrammaticScroll = true
        scrollView.contentOffset = CGPoint(x: CGFloat(index) * width, y: 0)
        isProgrammaticScroll = false
        currentVisual = index
        syncDot(for: index)
    }

    /// 程序化滚动到可视页：可带动画；suppress 运行期全部 scrollViewDidScroll。
    /// - Parameters:
    ///   - index: 目标可视页。
    ///   - animated: 是否动画。动画期间 isProgrammaticScroll 保持 true，
    ///     由 scrollViewWillBeginDragging（用户接管）或 scrollViewDidEndScrollingAnimation 清掉。
    ///   - reportReal: 是否把目标真实页当作「这次翻页」上报（自动播才上报；下行命令不上报）。
    private func programmaticScroll(to index: Int, animated: Bool, reportReal: Int? = nil) {
        let width = max(scrollView.bounds.width, 1)
        guard index >= 0, index < renderedSlides.count else { return }
        if index == currentVisual {
            syncDot(for: index)
            return
        }
        currentVisual = index
        let real = index % max(realCount, 1)
        lastReportedReal = real
        syncDot(for: index)

        isProgrammaticScroll = true
        scrollView.setContentOffset(CGPoint(x: CGFloat(index) * width, y: 0), animated: animated)
        if !animated {
            isProgrammaticScroll = false
            // 非动画命令式滚动落位后立刻收进中带，维持「停在 B 带」的不变量
            normalizeVisualPosition()
        }

        if let reportReal {
            onIntent?(.pageChanged(reportReal))
        }
    }

    /// 一键同步圆点（真实页 = 可视页 % N）。
    private func syncDot(for visual: Int) {
        guard realCount > 0 else { return }
        pageControl.currentPage = min(visual % realCount, realCount - 1)
    }

    // MARK: - 自动播（Timer）

    private func updateTimer(_ interval: Double?) {
        autoPlayInterval = interval
        timer?.invalidate()
        timer = nil
        guard let interval = interval, interval > 0, !slides.isEmpty else { return }

        // Timer 会 retain target：用私有弱代理 WeakTimerProxy（只持 weak owner，
        // 回调经 assumeIsolated 落回主演员），避免 view ↔ timer 相互保活。
        // ⚠️ 不走闭包式共享代理：strict concurrency 会把跨边界的闭包当可发送值
        //    检查而告警，而「weak owner 类引用」不触发该检查（已验收的正解）。
        let timer = Timer(timeInterval: interval,
                          target: WeakTimerProxy(self),
                          selector: #selector(WeakTimerProxy.fire),
                          userInfo: nil,
                          repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @MainActor
    fileprivate func timerFired() {
        // 用户正在拖拽 / 惯性减速时不插队，等平稳了再说
        guard !scrollView.isTracking && !scrollView.isDecelerating else { return }
        guard realCount >= 2 else { return }

        if isInfinite {
            // 先瞬移回中带（同页无感），保证接下来一定能「向前」走：
            // 停在 C 带末尾的自动播若直接 +1 会越界产生回卷动画，必须先归一。
            let mid = CarouselGeometry.middle(currentVisual, realCount: realCount, isInfinite: true)
            if mid != currentVisual {
                teleport(to: mid)
            }
            // 始终向前：中带内 +1；到 B 带尾（2N-1）下一步是 C 带开头（2N），
            // 落位后 didEndScrollingAnimation → normalize 瞬移回 B 带开头（N）。
            var next = currentVisual + 1
            if next >= renderedSlides.count { next = realCount }   // 兜底，正常到不了
            programmaticScroll(to: next, animated: true, reportReal: next % realCount)
        } else {
            let next = currentVisual + 1
            guard next < realCount else { return }   // 有限模式：到最后一张就不再自动回头
            programmaticScroll(to: next, animated: true, reportReal: next)
        }
    }

    // MARK: - 事件

    @objc private func handlePageTap(_ recognizer: UITapGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let index = view.tag
        guard !renderedSlides.isEmpty, index >= 0, index < renderedSlides.count else { return }
        onIntent?(.tapped(slides[index % slides.count]))
    }

    // MARK: - 页卡片

    private func makePage(for slide: CarouselSlide) -> UIView {
        // 主题：makePage 只被 rebuildPages 调用（apply 之内），活取当前生效主题，
        // 换肤后 apply 的 themeChanged 强制 rebuildPages → 这里必然重跑。
        let theme = resolvedTheme()

        // 整页容器：frame 排版（layoutSubviews 按页宽摆放），只裁边。
        // 无障碍：不给 page 容器设 isAccessibilityElement=true（会盖掉内部文本），
        // 内部 title/subtitle 是 UILabel 子视图，VoiceOver 默认逐标签可达，仅此确认即可。
        let page = UIView().chain()
            .clipsToBounds(true)
            .build()

        // 卡片：tone 浅底 + 圆角；两侧留缝走下方 SnapKit
        let card = UIView().chain()
            .backgroundColor(theme.softBackground(for: slide.tone))
            .cornerRadius(12)
            .added(to: page)
            .build()

        let titleLabel = UILabel().chain()
            .font(ComponentTypography.carouselTitleFont())
            .textColor(theme.color(for: slide.tone))
            .textAlignment(.center)
            .text(slide.title)
            .added(to: card)
            .build()

        let subtitleLabel = UILabel().chain()
            .font(ComponentTypography.carouselSubtitleFont())
            .textColor(.secondaryLabel)
            .textAlignment(.center)
            .text(slide.subtitle)
            .isHidden(slide.subtitle == nil)
            .added(to: card)
            .build()

        // 卡片两侧留缝：paging 按整页翻，让相邻页在边缘可见
        card.snp.makeConstraints { make in
            make.top.equalTo(page).offset(6)
            make.leading.equalTo(page).offset(10)
            make.trailing.equalTo(page).offset(-10)
            make.bottom.equalTo(page).offset(-6)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(card).offset(16)
            make.trailing.equalTo(card).offset(-16)
            make.centerY.equalTo(card).offset(subtitleLabel.isHidden ? 0 : -12)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
        }
        return page
    }
}

// MARK: - UIScrollViewDelegate

extension CarouselBridgeView: UIScrollViewDelegate {

    /// 滚动上报：按页取整 + 真实页去重；程序化滚动期间被压制，不把命令当用户意图。
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 程序化滚动引发的回调：位置去哪里由命令决定，不是用户意图
        guard !isProgrammaticScroll else { return }
        let width = scrollView.bounds.width
        guard width > 0, !renderedSlides.isEmpty else { return }

        let page = min(max(Int((scrollView.contentOffset.x / width).rounded()), 0), renderedSlides.count - 1)
        currentVisual = page
        syncDot(for: page)

        // 按真实页去重：同一页内的微小偏移不上报
        let real = page % max(realCount, 1)
        guard real != lastReportedReal else { return }
        lastReportedReal = real
        onIntent?(.pageChanged(real))
    }

    /// 用户开始拖动：接管路径，打断可能进行中的程序化动画。
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 用户接管：打断可能正在进行的程序化动画 → 后续回调全部回到用户路径
        isProgrammaticScroll = false
    }

    /// 松手停止：没有惯性时立即收位（归一进中带）。
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // 松手即有轻微拖动但没惯性：直接收位
        if !decelerate {
            normalizeVisualPosition()
        }
    }

    /// 惯性滚动结束：归一进中带。
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        normalizeVisualPosition()
    }

    /// 动画式程序化滚动落位：结束压制，越界则瞬移回绕。
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        // 动画式程序化滚动落位：结束压制 → 若越过中带则瞬移回绕
        isProgrammaticScroll = false
        normalizeVisualPosition()
    }
}

// MARK: - Timer 的弱代理

/// Timer 强持有 target：用 NSObject 代理只持 weak owner，避免 CarouselBridgeView ↔ Timer
/// 相互保活。回调落在主 RunLoop，assumeIsolated 让编译器认可「主线程就是主演员」。
/// 拆桥路径：teardown 里必须 timer.invalidate() + 置 nil，否则空转。
private final class WeakTimerProxy: NSObject {
    private weak var owner: CarouselBridgeView?

    init(_ owner: CarouselBridgeView) {
        self.owner = owner
    }

    @objc func fire() {
        guard let owner else { return }
        MainActor.assumeIsolated {
            owner.timerFired()
        }
    }
}