import SwiftUI

struct DaySalesView: View {
    let date: String

    @StateObject private var vm = DaySalesViewModel()

    private static let soldAtParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let soldAtFallbackParser = ISO8601DateFormatter()

    private static let soldAtFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = TimeZone(identifier: "Europe/London")
        return f
    }()

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

    var body: some View {
        ZStack {
            DashboardBackground()

            ScrollView {
                VStack(spacing: 12) {
                    if let payload = vm.payload {
                        if payload.items.isEmpty {
                            emptyCard
                        } else {
                            ForEach(payload.items) { item in
                                saleCard(item)
                            }
                        }
                    } else {
                        ProgressView("Loading sales...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .vintageCard()
                    }

                    if let errorText = vm.errorText, !errorText.isEmpty {
                        InlineNotice(text: errorText, tone: BrandTheme.danger, systemImage: "exclamationmark.triangle.fill")
                            .vintageCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(date)
        .task { await vm.load(date: date) }
        .refreshable { await vm.load(date: date) }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No sales recorded")
                .font(.headline)
                .foregroundStyle(BrandTheme.ink)
            Text("No Shopify or manual entries found for this day.")
                .font(.subheadline)
                .foregroundStyle(BrandTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vintageCard()
    }

    // MARK: - Sale Card

    @ViewBuilder
    private func saleCard(_ item: DaySaleItem) -> some View {
        let lines = item.line_items ?? []
        let hasCommission = item.has_commission ?? false
        // The number we headline is what the store actually keeps. For
        // consignment orders that's only the 15% commission, so it never looks
        // like the shop banked the full sale price.
        let storeNet = item.store_net ?? item.amount ?? 0
        let gross = item.amount ?? storeNet

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(formatTime(item.sold_at))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.inkSoft)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(gbp(storeNet))
                        .font(.callout.weight(.bold))
                        .foregroundStyle(BrandTheme.accent)
                    if hasCommission && gross > storeNet {
                        Text("\(gbp(gross)) sale")
                            .font(.caption2)
                            .foregroundStyle(BrandTheme.inkSoft)
                    }
                }
            }

            if !lines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(lines) { line in
                        lineRow(line)
                    }
                }
            } else {
                // Manual entry or an order without a per-line breakdown.
                Text(item.description)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                StatusPill(
                    text: item.kind == "manual" ? "MANUAL" : "SHOPIFY",
                    tone: item.kind == "manual" ? BrandTheme.success : BrandTheme.accent
                )
                if hasCommission {
                    StatusPill(text: "CONSIGNMENT", tone: BrandTheme.inkSoft)
                }
                if lines.count > 1 {
                    StatusPill(text: "\(lines.count) ITEMS", tone: BrandTheme.inkSoft)
                }
                if let orderName = item.order_name, !orderName.isEmpty {
                    Text(orderName)
                        .font(.caption)
                        .foregroundStyle(BrandTheme.inkSoft)
                }
            }

            if let note = item.note, !note.isEmpty {
                Text("Note: \(note)")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.inkSoft)
            }
        }
        .vintageCard()
    }

    @ViewBuilder
    private func lineRow(_ line: DayLineItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(cleanName(line.name))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if line.is_commission, let seller = line.seller {
                    Text("\(seller) · you keep 15%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BrandTheme.success)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                if line.quantity > 1 {
                    Text("x\(line.quantity)")
                        .font(.caption2)
                        .foregroundStyle(BrandTheme.inkSoft)
                }
                // Store-net per line: full price for own stock, 15% for consignment.
                Text(gbp(line.store_net))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BrandTheme.ink)
                if line.is_commission && line.gross > line.store_net {
                    Text("\(gbp(line.gross)) sale")
                        .font(.caption2)
                        .foregroundStyle(BrandTheme.inkSoft)
                }
            }
        }
    }

    private func formatTime(_ iso: String) -> String {
        if let date = Self.soldAtParser.date(from: iso) ?? Self.soldAtFallbackParser.date(from: iso) {
            return Self.soldAtFormatter.string(from: date)
        }
        return "--:--"
    }

    private func cleanName(_ name: String) -> String {
        let patterns = ["TA - ", "TA-", "TA:", "TA ",
                        "AA - ", "AA-", "AA:", "AA ",
                        "HW - ", "HW-", "HW:", "HW "]
        for prefix in patterns where name.hasPrefix(prefix) {
            return String(name.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return name
    }
}
