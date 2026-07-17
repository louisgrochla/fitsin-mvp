import SwiftUI
import UIKit

struct RootTabView: View {
    @StateObject private var todayVM = TodayViewModel()
    @StateObject private var monthVM = MonthViewModel()
    @StateObject private var eventsVM = EventsViewModel()
    @StateObject private var rotaVM = RotaViewModel()
    @StateObject private var router = NotificationRouter.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(BrandTheme.paper)
        appearance.shadowColor = UIColor(BrandTheme.outline)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(BrandTheme.ink)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(BrandTheme.ink),
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(BrandTheme.inkSoft)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(BrandTheme.inkSoft),
            .font: UIFont.systemFont(ofSize: 11, weight: .regular)
        ]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            TodayView(vm: todayVM, rotaVM: rotaVM)
                .tabItem {
                    Label("Today", systemImage: "chart.line.uptrend.xyaxis")
                }

            MonthView(vm: monthVM)
                .tabItem {
                    Label("Month", systemImage: "calendar")
                }

            EventsView(vm: eventsVM)
                .tabItem {
                    Label("Events", systemImage: "list.bullet.rectangle")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(BrandTheme.ink)
        .sheet(item: $router.pending) { link in
            NavigationStack {
                Group {
                    switch link {
                    case .day(let date):
                        DaySalesView(date: date)
                    case .seller:
                        SellerSalesView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { router.pending = nil }
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    async let t: Void = todayVM.load()
                    async let m: Void = monthVM.load()
                    async let e: Void = eventsVM.load()
                    async let r: Void = rotaVM.load()
                    _ = await (t, m, e, r)
                }
            }
        }
    }
}
