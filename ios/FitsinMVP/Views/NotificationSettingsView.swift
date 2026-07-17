import SwiftUI

struct NotificationSettingsView: View {
    @State private var newSale = true
    @State private var myCommissionSale = false
    @State private var dailySummary = true
    @State private var rotaReminder = true
    @State private var sellerPrefix = ""
    @State private var loaded = false
    @State private var animateIn = false

    private let sellerOptions = ["TA", "AA"]

    var body: some View {
        ZStack {
            DashboardBackground()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection

                    VStack(spacing: 0) {
                        toggleRow(
                            icon: "cart.fill",
                            title: "New Sale Alerts",
                            subtitle: "Every Shopify sale",
                            isOn: $newSale
                        )

                        Divider().overlay(BrandTheme.divider).padding(.horizontal, 20)

                        toggleRow(
                            icon: "person.fill",
                            title: "My Commission Sales",
                            subtitle: "Only sales matching your prefix",
                            isOn: $myCommissionSale
                        )

                        if myCommissionSale {
                            prefixPicker
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Divider().overlay(BrandTheme.divider).padding(.horizontal, 20)

                        toggleRow(
                            icon: "chart.bar.fill",
                            title: "Daily Summary",
                            subtitle: "Evening recap at 6pm",
                            isOn: $dailySummary
                        )

                        Divider().overlay(BrandTheme.divider).padding(.horizontal, 20)

                        toggleRow(
                            icon: "alarm.fill",
                            title: "Rota Reminders",
                            subtitle: "Evening before you're opening",
                            isOn: $rotaReminder
                        )
                    }
                    .background(BrandTheme.surfaceStrong)
                    .overlay(
                        VStack {
                            Divider().overlay(BrandTheme.outline)
                            Spacer()
                            Divider().overlay(BrandTheme.outline)
                        }
                    )
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 12)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            animateIn = false
            withAnimation(.easeOut(duration: 0.4)) {
                animateIn = true
            }
            await loadPreferences()
        }
        .onChange(of: newSale) { _, _ in saveIfLoaded() }
        .onChange(of: myCommissionSale) { _, _ in saveIfLoaded() }
        .onChange(of: dailySummary) { _, _ in saveIfLoaded() }
        .onChange(of: rotaReminder) { _, _ in saveIfLoaded() }
        .onChange(of: sellerPrefix) { _, _ in saveIfLoaded() }
    }

    private func loadPreferences() async {
        guard let token = KeychainStore.readDeviceToken(), !token.isEmpty else {
            loaded = true
            return
        }

        if let device = try? await APIClient.shared.getDevice(token: token) {
            let prefs = device.preferences
            newSale = prefs.newSale
            myCommissionSale = prefs.myCommissionSale
            dailySummary = prefs.dailySummary
            rotaReminder = prefs.rotaReminder
            sellerPrefix = prefs.sellerPrefix ?? ""
        }

        // Enable saves only after applying loaded values so seeding them
        // doesn't trigger a redundant write back to the server.
        loaded = true
    }

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("NOTIFICATIONS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(BrandTheme.inkSoft)
            Text("Choose what you get notified about")
                .font(.caption)
                .foregroundStyle(BrandTheme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(BrandTheme.ink)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BrandTheme.ink)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(BrandTheme.inkSoft)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(BrandTheme.ink)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var prefixPicker: some View {
        HStack(spacing: 8) {
            Text("I am:")
                .font(.caption)
                .foregroundStyle(BrandTheme.inkSoft)

            ForEach(sellerOptions, id: \.self) { prefix in
                Button {
                    sellerPrefix = prefix
                } label: {
                    Text(prefix)
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(sellerPrefix == prefix ? BrandTheme.ink : BrandTheme.ink.opacity(0.06))
                        )
                        .foregroundStyle(sellerPrefix == prefix ? .white : BrandTheme.inkSoft)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func saveIfLoaded() {
        guard loaded else { return }
        guard let token = KeychainStore.readDeviceToken(), !token.isEmpty else { return }

        let prefs: [String: Any] = [
            "new_sale": newSale,
            "my_commission_sale": myCommissionSale,
            "daily_summary": dailySummary,
            "rota_reminder": rotaReminder,
            "seller_prefix": sellerPrefix
        ]

        Task {
            try? await APIClient.shared.updateDevicePreferences(token: token, preferences: prefs)
        }
    }
}
