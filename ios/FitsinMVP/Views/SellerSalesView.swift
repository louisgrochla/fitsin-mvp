import SwiftUI

struct SellerSalesView: View {
    @StateObject private var vm = SellerSalesViewModel()
    @State private var animateIn = false

    private static let gbpFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "GBP"
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private func gbp(_ value: Double) -> String {
        Self.gbpFormatter.string(from: NSNumber(value: value)) ?? "£0"
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM, HH:mm"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private func formatDate(_ iso: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        if let date = parser.date(from: iso) ?? fallback.date(from: iso) {
            return Self.timeFmt.string(from: date)
        }
        return iso
    }

    var body: some View {
        ZStack {
            DashboardBackground()

            ScrollView {
                VStack(spacing: 0) {
                    if vm.isLoading && vm.sellers.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        commissionHeader
                        sellerTabs
                        sellerSummary
                        itemsList
                    }

                    if let error = vm.errorText {
                        InlineNotice(text: error, tone: BrandTheme.danger, systemImage: "wifi.exclamationmark")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 16)
            }
            .refreshable { await vm.load() }
        }
        .navigationTitle("Seller Sales")
        .task {
            animateIn = false
            withAnimation(.easeOut(duration: 0.4)) {
                animateIn = true
            }
            await vm.load()
        }
    }

    // MARK: - Header

    private var commissionHeader: some View {
        VStack(spacing: 4) {
            Text("COMMISSION TRACKING")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(BrandTheme.inkSoft)
            Text("\(Int(vm.commissionRate * 100))% store commission")
                .font(.caption)
                .foregroundStyle(BrandTheme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Seller Tabs

    private var sellerTabs: some View {
        HStack(spacing: 0) {
            sellerTab(label: "All", seller: nil)
            ForEach(vm.sellers) { s in
                sellerTab(label: s.seller, seller: s.seller)
            }
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

    private func sellerTab(label: String, seller: String?) -> some View {
        let isSelected = vm.selectedSeller == seller

        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                vm.selectedSeller = seller
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(isSelected ? BrandTheme.ink : BrandTheme.inkSoft)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Rectangle()
                            .fill(BrandTheme.ink)
                            .frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Summary

    private var sellerSummary: some View {
        let summaries = vm.selectedSeller != nil
            ? vm.sellers.filter { $0.seller == vm.selectedSeller }
            : vm.sellers

        let totalGross = summaries.reduce(0) { $0 + $1.total_gross }
        let totalCommission = summaries.reduce(0) { $0 + $1.total_commission }
        let totalNet = summaries.reduce(0) { $0 + $1.total_net }
        let totalItems = summaries.reduce(0) { $0 + $1.item_count }
        let totalPaid = summaries.reduce(0) { $0 + ($1.total_paid ?? 0) }
        let totalOutstanding = summaries.reduce(0) { $0 + ($1.total_unpaid ?? max(0, $1.total_net)) }

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("TOTAL SOLD")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(BrandTheme.inkSoft)
                    Text(gbp(totalGross))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandTheme.ink)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 32).overlay(BrandTheme.divider)

                VStack(spacing: 4) {
                    Text("WE KEEP")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(BrandTheme.inkSoft)
                    Text(gbp(totalCommission))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandTheme.success)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 32).overlay(BrandTheme.divider)

                VStack(spacing: 4) {
                    Text("OWED")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(BrandTheme.inkSoft)
                    Text(gbp(totalNet))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandTheme.danger)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 20)

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("PAID OUT")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(BrandTheme.inkSoft)
                    Text(gbp(totalPaid))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandTheme.success)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 24).overlay(BrandTheme.divider)

                VStack(spacing: 2) {
                    Text("STILL OWED")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(BrandTheme.inkSoft)
                    Text(gbp(totalOutstanding))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandTheme.danger)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 10)

            HStack {
                Spacer()
                Text("\(totalItems) items sold")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.inkSoft)
                Spacer()
            }
            .padding(.bottom, 14)
        }
        .background(BrandTheme.surfaceStrong)
        .overlay(
            VStack {
                Spacer()
                Divider().overlay(BrandTheme.outline)
            }
        )
    }

    // MARK: - Items List

    private var itemsList: some View {
        let filtered = vm.filteredItems

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Sales")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(0.3)
                    .foregroundStyle(BrandTheme.ink)
                Spacer()
                Text("\(filtered.count) items")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.inkSoft)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            if filtered.isEmpty {
                Text("No commissioned sales this month.")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.inkSoft)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider().overlay(BrandTheme.divider).padding(.horizontal, 20)
                        }

                        let isPaid = item.paid ?? false

                        HStack(spacing: 10) {
                            Button {
                                Task { await vm.setPaid(item, paid: !isPaid) }
                            } label: {
                                Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(isPaid ? BrandTheme.success : BrandTheme.inkSoft.opacity(0.5))
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(cleanItemName(item.item_name))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(BrandTheme.ink)
                                    .lineLimit(1)
                                    .strikethrough(isPaid, color: BrandTheme.inkSoft)
                                HStack(spacing: 6) {
                                    Text(item.seller)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(BrandTheme.ink.opacity(0.08)))
                                        .foregroundStyle(BrandTheme.ink)
                                    Text(formatDate(item.sold_at))
                                        .font(.system(size: 11))
                                        .foregroundStyle(BrandTheme.inkSoft)
                                    if isPaid {
                                        Text("PAID")
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(BrandTheme.success.opacity(0.15)))
                                            .foregroundStyle(BrandTheme.success)
                                    }
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(gbp(item.seller_net))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(BrandTheme.ink)
                                Text("owed · \(gbp(item.gross)) sold")
                                    .font(.system(size: 10))
                                    .foregroundStyle(BrandTheme.inkSoft)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .opacity(isPaid ? 0.6 : 1)
                    }
                }
            }
        }
        .background(BrandTheme.surfaceStrong)
        .overlay(
            VStack {
                Divider().overlay(BrandTheme.outline)
                Spacer()
            }
        )
        .padding(.top, 16)
    }

    private func cleanItemName(_ name: String) -> String {
        // Remove seller prefix like "TA - " or "TA-" or "TA:"
        let patterns = ["TA - ", "TA-", "TA:", "TA ",
                        "AA - ", "AA-", "AA:", "AA ",
                        "HW - ", "HW-", "HW:", "HW "]
        for prefix in patterns {
            if name.hasPrefix(prefix) {
                return String(name.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return name
    }
}
