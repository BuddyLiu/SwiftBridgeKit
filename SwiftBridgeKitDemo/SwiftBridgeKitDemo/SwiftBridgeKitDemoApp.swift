//
//  SwiftBridgeKitDemoApp.swift
//  SwiftBridgeKitDemo
//
//  Created by bo.liu on 2026/9/17.
//

import SwiftUI

@main
struct SwiftBridgeKitDemoApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                root()
            }
        }
    }

    /// 支持 `DEMO=03` 这样的环境变量直接进某页，方便逐页验证：
    /// xcrun simctl launch --console booted liu.SwiftBridgeKitDemo 的基础上，
    /// 用 `SIMCTL_CHILD_DEMO=03` 指定要直达的页面。
    private func root() -> some View {
        guard let raw = ProcessInfo.processInfo.environment["DEMO"],
              let page = Int(raw) else { return AnyView(DemoList()) }
        return AnyView(demoPage(page))
    }

    @ViewBuilder
    private func demoPage(_ page: Int) -> some View {
        switch page {
        case 1: Demo01_RatingBridgePage()
        case 2: Demo02_AsyncRatioBridgePage()
        case 3: Demo03_FormBridgePage()
        case 4: Demo04_ScrollBridgePage()
        case 5: Demo05_TableBridgePage()
        case 6: Demo06_CollectionBridgePage()
        case 7: Demo07_ComponentsGalleryPage()
        case 8: Demo08_ComplexViewsGalleryPage()
        case 9: Demo09_ExtendedGalleryPage()
        case 10: Demo10_FacilitiesGalleryPage()
        default: DemoList()
        }
    }
}

/// Demo 入口：列出各演示页，方便在模拟器上逐页验证。
struct DemoList: View {
    var body: some View {
        List {
            Section("框架教学（01–06）") {
                NavigationLink("01 · 最小闭环（状态下行 / 意图上行 / 抑制）") {
                    Demo01_RatingBridgePage()
                }
                NavigationLink("02 · 异步比例回流") {
                    Demo02_AsyncRatioBridgePage()
                }
                NavigationLink("03 · 表单（TextField / TextView）") {
                    Demo03_FormBridgePage()
                }
                NavigationLink("04 · 可滚动容器（ScrollView）") {
                    Demo04_ScrollBridgePage()
                }
                NavigationLink("05 · 列表（TableView）") {
                    Demo05_TableBridgePage()
                }
                NavigationLink("06 · 网格（CollectionView）") {
                    Demo06_CollectionBridgePage()
                }
            }

            Section("组件库（07–10）") {
                NavigationLink("07 · 组件库（SwiftBridgeComponents）") {
                    Demo07_ComponentsGalleryPage()
                }
                NavigationLink("08 · 复杂视图（List / Grid / Carousel）") {
                    Demo08_ComplexViewsGalleryPage()
                }
                NavigationLink("09 · 组件扩展（Progress / Search / Toast）") {
                    Demo09_ExtendedGalleryPage()
                }
                NavigationLink("10 · 三项设施（主题 / 无障碍 / 弹层）") {
                    Demo10_FacilitiesGalleryPage()
                }
            }
        }
        .navigationTitle("SwiftBridgeKit Demo")
    }
}

#Preview {
    NavigationStack {
        DemoList()
    }
}
