import Foundation

struct WeekProjection: Identifiable {
    let id: String
    let date: Date
    let actual: Double
    let target: Double
}

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var data: TodayMetrics?
    @Published var weekAhead: [WeekProjection] = []
    @Published var errorText: String?
    @Published var manualEntryStatus: String?
    @Published var isSavingManualEntry = false
    private var refreshTask: Task<Void, Never>?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    func loadCached() {
        guard data == nil else { return }
        if let cached: TodayMetrics = LocalCache.read(TodayMetrics.self, key: "today.json") {
            data = cached
            if let cachedMonth: MonthMetrics = LocalCache.read(MonthMetrics.self, key: "month.json") {
                weekAhead = makeWeekAhead(from: cachedMonth.days)
            }
        }
    }

    func load() async {
        do {
            async let todayTask = APIClient.shared.getToday()
            async let monthTask = APIClient.shared.getMonth()

            let payload = try await todayTask
            let monthPayload = try await monthTask

            data = payload
            weekAhead = makeWeekAhead(from: monthPayload.days)

            LocalCache.write(payload, key: "today.json")
            LocalCache.write(monthPayload, key: "month.json")
            errorText = payload.warning
        } catch {
            if case APIError.unauthorized = error {
                errorText = "Access code is invalid. Please re-enter it."
                return
            }
            if case APIError.noCode = error {
                errorText = "No access code saved."
                return
            }
            if data == nil {
                if let cached: TodayMetrics = LocalCache.read(TodayMetrics.self, key: "today.json") {
                    data = cached
                    if let cachedMonth: MonthMetrics = LocalCache.read(MonthMetrics.self, key: "month.json") {
                        weekAhead = makeWeekAhead(from: cachedMonth.days)
                    }
                }
            }
            errorText = data != nil ? "Showing cached data (offline or server unavailable)." : "Could not load today metrics."
        }
    }

    func addManualEntry(
        amount: Double,
        source: ManualSource,
        description: String?,
        note: String?,
        date: String? = nil
    ) async {
        isSavingManualEntry = true
        defer { isSavingManualEntry = false }

        do {
            _ = try await APIClient.shared.createManualEntry(
                amount: amount,
                source: source,
                description: description,
                note: note,
                date: date
            )
            manualEntryStatus = "Manual sale logged."
            // Refresh metrics off the critical path so logging several sales in a
            // row stays snappy — the form is ready again as soon as the POST returns.
            Task { await load() }
        } catch {
            manualEntryStatus = "Could not save manual sale."
        }
    }

    private func makeWeekAhead(from days: [MonthDay]) -> [WeekProjection] {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let start = cal.startOfDay(for: now)
        guard let end = cal.date(byAdding: .day, value: 6, to: start) else { return [] }

        return days.compactMap { day in
            guard let date = Self.dateFormatter.date(from: day.date) else { return nil }
            let normalized = cal.startOfDay(for: date)
            guard normalized >= start && normalized <= end else { return nil }
            return WeekProjection(id: day.date, date: normalized, actual: day.actual, target: day.target)
        }
        .sorted { $0.date < $1.date }
    }

    func startAutoRefresh(intervalSeconds: UInt64 = 60) {
        stopAutoRefresh()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)
                if Task.isCancelled { break }
                await self.load()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
