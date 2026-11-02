import Foundation
import Combine

@MainActor
final class MonthViewModel: ObservableObject {
    @Published var data: MonthMetrics?
    @Published var lastMonthData: MonthMetrics?
    @Published var errorText: String?
    @Published var monthGoal: Double?
    @Published var isSavingGoal = false
    @Published var isLoading = false
    @Published var lastMonthErrorText: String?
    private var loadTask: Task<Void, Never>?
    private let fetchMonth: (String?) async throws -> MonthMetrics
    private let usesCache: Bool

    init(usesCache: Bool = true, fetchMonth: @escaping (String?) async throws -> MonthMetrics = { month in
        if let month { return try await APIClient.shared.getMonth(month: month) }
        return try await APIClient.shared.getMonth()
    }) {
        self.usesCache = usesCache
        self.fetchMonth = fetchMonth
    }

    private var refreshTask: Task<Void, Never>?

    private static let monthFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        fmt.timeZone = TimeZone(identifier: "Europe/London")
        return fmt
    }()

    private var monthKey: String {
        Self.monthFormatter.string(from: Date())
    }

    private var lastMonthKey: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let lastMonth = cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return Self.monthFormatter.string(from: lastMonth)
    }

    func loadCached() {
        if let data, data.month != monthKey {
            self.data = nil
            monthGoal = nil
        }
        if let lastMonthData, lastMonthData.month != lastMonthKey { self.lastMonthData = nil }
        guard usesCache else { return }
        if data == nil,
           let cached: MonthMetrics = LocalCache.read(MonthMetrics.self, key: "month.json"),
           cached.month == monthKey {
            data = cached
            monthGoal = cached.month_goal
            errorText = "Saved month data — refreshing…"
        }
        if lastMonthData == nil,
           let cached: MonthMetrics = LocalCache.read(MonthMetrics.self, key: "month-last.json"),
           cached.month == lastMonthKey {
            lastMonthData = cached
            lastMonthErrorText = "Saved previous month data — refreshing…"
        }
    }

    func load() async {
        if let loadTask { await loadTask.value; return }
        loadCached()
        let task = Task {
            async let current: Void = refreshCurrentMonth()
            async let previous: Void = refreshPreviousMonth()
            _ = await (current, previous)
            loadTask = nil
        }
        loadTask = task
        await task.value
    }

    private func refreshCurrentMonth() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let payload = try await fetchMonth(nil)
            data = payload
            // /v1/month already includes the goal used to calculate its targets.
            monthGoal = payload.month_goal
            if usesCache { LocalCache.write(payload, key: "month.json") }
            errorText = payload.warning
        } catch {
            if case APIError.unauthorized = error {
                errorText = "Access code is invalid. Please re-enter it."
            } else if case APIError.noCode = error {
                errorText = "No access code saved."
            } else {
                errorText = data != nil ? "Showing saved month data; refresh failed." : "Could not load month metrics."
            }
        }
    }

    private func refreshPreviousMonth() async {
        do {
            let payload = try await fetchMonth(lastMonthKey)
            lastMonthData = payload
            if usesCache { LocalCache.write(payload, key: "month-last.json") }
            lastMonthErrorText = payload.warning
        } catch {
            lastMonthErrorText = lastMonthData != nil ? "Showing saved previous month data; refresh failed." : "Previous month is unavailable. Pull to retry."
        }
    }

    func saveMonthGoal(_ goal: Double?) async {
        isSavingGoal = true
        defer { isSavingGoal = false }

        do {
            let saved = try await APIClient.shared.setMonthGoal(month: monthKey, goal: goal)
            monthGoal = saved.goal
            if let loadTask { await loadTask.value }
            await load()
        } catch {
            errorText = "Could not save month goal."
        }
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
