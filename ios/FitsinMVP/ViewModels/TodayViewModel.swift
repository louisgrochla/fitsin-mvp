import Foundation
import Combine

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
    @Published var weekErrorText: String?
    @Published var weekUpdatedAt: String?
    @Published var isLoadingToday = false
    @Published var isLoadingWeek = false
    @Published var manualEntryStatus: String?
    @Published var manualEntryFailed = false
    @Published var isSavingManualEntry = false
    private var refreshTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var weekMonth: String?
    private let fetchToday: () async throws -> TodayMetrics
    private let fetchMonth: () async throws -> MonthMetrics
    private let saveEntry: (Double, ManualSource, String?, String?, String?) async throws -> Void
    private let usesCache: Bool

    init(
        usesCache: Bool = true,
        fetchToday: @escaping () async throws -> TodayMetrics = { try await APIClient.shared.getToday() },
        fetchMonth: @escaping () async throws -> MonthMetrics = { try await APIClient.shared.getMonth() },
        saveEntry: @escaping (Double, ManualSource, String?, String?, String?) async throws -> Void = { amount, source, description, note, date in
            _ = try await APIClient.shared.createManualEntry(amount: amount, source: source, description: description, note: note, date: date)
        }
    ) {
        self.usesCache = usesCache
        self.fetchToday = fetchToday
        self.fetchMonth = fetchMonth
        self.saveEntry = saveEntry
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    func loadCached() {
        let currentMonth = String(Self.dateFormatter.string(from: Date()).prefix(7))
        if let data, !data.updated_at.hasPrefix(Self.dateFormatter.string(from: Date())) {
            self.data = nil
        }
        if let weekMonth, weekMonth != currentMonth {
            weekAhead = []
            weekUpdatedAt = nil
            self.weekMonth = nil
        }
        guard usesCache else { return }
        if data == nil,
           let cached: TodayMetrics = LocalCache.read(TodayMetrics.self, key: "today.json"),
           cached.updated_at.hasPrefix(Self.dateFormatter.string(from: Date())) {
            data = cached
            errorText = "Saved Today data — refreshing…"
        }
        if weekUpdatedAt == nil,
           let cached: MonthMetrics = LocalCache.read(MonthMetrics.self, key: "month.json"),
           cached.month == currentMonth {
            weekAhead = makeWeekAhead(from: cached.days)
            weekMonth = cached.month
            weekUpdatedAt = cached.updated_at
            weekErrorText = "Saved week data — refreshing…"
        }
    }

    func load() async {
        if let loadTask { await loadTask.value; return }
        loadCached()
        let task = Task {
            async let today: Void = refreshToday()
            async let week: Void = refreshWeek()
            _ = await (today, week)
            loadTask = nil
        }
        loadTask = task
        await task.value
    }

    private func refreshToday() async {
        isLoadingToday = true
        defer { isLoadingToday = false }
        do {
            let payload = try await fetchToday()
            data = payload
            if usesCache { LocalCache.write(payload, key: "today.json") }
            errorText = payload.warning
        } catch {
            errorText = failureMessage(error, section: "Today", hasData: data != nil)
        }
    }

    private func refreshWeek() async {
        isLoadingWeek = true
        defer { isLoadingWeek = false }
        do {
            let payload = try await fetchMonth()
            weekMonth = payload.month
            weekAhead = makeWeekAhead(from: payload.days)
            weekUpdatedAt = payload.updated_at
            if usesCache { LocalCache.write(payload, key: "month.json") }
            weekErrorText = payload.warning
        } catch {
            weekErrorText = failureMessage(error, section: "week", hasData: weekUpdatedAt != nil)
        }
    }

    private func failureMessage(_ error: Error, section: String, hasData: Bool) -> String {
        if case APIError.unauthorized = error { return "Access code is invalid. Please re-enter it." }
        if case APIError.noCode = error { return "No access code saved." }
        return hasData ? "Showing saved \(section) data; refresh failed. Pull to retry." : "Could not load \(section) data. Pull to retry."
    }

    @discardableResult
    func addManualEntry(
        amount: Double,
        source: ManualSource,
        description: String?,
        note: String?,
        date: String? = nil
    ) async -> Bool {
        guard !isSavingManualEntry else { return false }
        isSavingManualEntry = true
        manualEntryFailed = false
        defer { isSavingManualEntry = false }
        do {
            try await saveEntry(amount, source, description, note, date)
            manualEntryStatus = "Manual sale logged."
            // Do not join work which started before the write was confirmed.
            Task {
                if let loadTask { await loadTask.value }
                await load()
            }
            return true
        } catch {
            manualEntryFailed = true
            manualEntryStatus = "Sale not confirmed. Your input is kept. Check recent entries before retrying."
            return false
        }
    }

    private func makeWeekAhead(from days: [MonthDay]) -> [WeekProjection] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 6, to: start) else { return [] }
        return days.compactMap { day in
            guard let date = Self.dateFormatter.date(from: day.date) else { return nil }
            let normalized = cal.startOfDay(for: date)
            guard normalized >= start && normalized <= end else { return nil }
            return WeekProjection(id: day.date, date: normalized, actual: day.actual, target: day.target)
        }.sorted { $0.date < $1.date }
    }

    func startAutoRefresh(intervalSeconds: UInt64 = 60) {
        stopAutoRefresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)
                if Task.isCancelled { break }
                await self?.load()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
