import SwiftUI
import UIKit

struct RootTabView: View {
    @StateObject private var todayVM = TodayViewModel()
    @StateObject private var monthVM = MonthViewModel()
    @StateObject private var eventsVM = EventsViewModel()
    @StateObject private var rotaVM = RotaViewModel()
    @StateObject private var router = NotificationRouter.shared
    @State private var selectedTab = 0
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
        TabView(selection: $selectedTab) {
            TodayView(vm: todayVM, rotaVM: rotaVM)
                .tag(0)
                .tabItem {
                    Label("Today", systemImage: "chart.line.uptrend.xyaxis")
                }

            MonthView(vm: monthVM)
                .tag(1)
                .tabItem {
                    Label("Month", systemImage: "calendar")
                }

            EventsView(vm: eventsVM)
                .tag(2)
                .tabItem {
                    Label("Events", systemImage: "list.bullet.rectangle")
                }

            SettingsView()
                .tag(3)
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
                    guard scenePhase == .active else { return }
                    switch selectedTab {
                    case 0:
                        todayVM.startAutoRefresh()
                        async let today: Void = todayVM.load()
                        async let rota: Void = rotaVM.load()
                        _ = await (today, rota)
                    case 1:
                        monthVM.startAutoRefresh()
                        await monthVM.load()
                    case 2:
                        await eventsVM.load()
                    default:
                        break
                    }
                }
            } else {
                todayVM.stopAutoRefresh()
                monthVM.stopAutoRefresh()
            }
        }
    }
}
