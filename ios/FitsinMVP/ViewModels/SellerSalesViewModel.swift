import Foundation

@MainActor
final class SellerSalesViewModel: ObservableObject {
    @Published var sellers: [SellerSummary] = []
    @Published var items: [SellerItem] = []
    @Published var commissionRate: Double = 0.15
    @Published var selectedSeller: String?
    @Published var errorText: String?
    @Published var isLoading = false

    private static let monthFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        fmt.timeZone = TimeZone(identifier: "Europe/London")
        return fmt
    }()

    var currentMonthKey: String {
        Self.monthFormatter.string(from: Date())
    }

    var filteredItems: [SellerItem] {
        guard let seller = selectedSeller else { return items }
        return items.filter { $0.seller == seller }
    }

    func load(month: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.getSellerSales(month: month ?? currentMonthKey)
            sellers = response.sellers
            items = response.items
            commissionRate = response.commission_rate
            errorText = nil
        } catch {
            errorText = "Could not load seller sales."
        }
    }

    // Toggle payout status with an optimistic local update so the UI responds
    // instantly; revert if the shared backend write fails.
    func setPaid(_ item: SellerItem, paid: Bool) async {
        applyPaid(itemId: item.id, paid: paid)
        do {
            try await APIClient.shared.setSellerItemPaid(itemId: item.id, paid: paid)
            errorText = nil
        } catch {
            applyPaid(itemId: item.id, paid: !paid)
            errorText = "Could not update payout status."
        }
    }

    private func applyPaid(itemId: String, paid: Bool) {
        guard let idx = items.firstIndex(where: { $0.id == itemId }) else { return }
        let old = items[idx]
        if (old.paid ?? false) == paid { return }

        items[idx] = SellerItem(
            id: old.id, seller: old.seller, item_name: old.item_name,
            quantity: old.quantity, gross: old.gross, commission: old.commission,
            seller_net: old.seller_net, paid: paid, sold_at: old.sold_at,
            date: old.date, order_name: old.order_name
        )

        if let sIdx = sellers.firstIndex(where: { $0.seller == old.seller }) {
            let s = sellers[sIdx]
            let delta = old.seller_net
            sellers[sIdx] = SellerSummary(
                seller: s.seller, total_gross: s.total_gross,
                total_commission: s.total_commission, total_net: s.total_net,
                total_paid: (s.total_paid ?? 0) + (paid ? delta : -delta),
                total_unpaid: (s.total_unpaid ?? 0) + (paid ? -delta : delta),
                item_count: s.item_count
            )
        }
    }
}
