import XCTest
import Combine

// Compiled in a separate hostless test bundle. No app startup, network,
// Keychain access or cache I/O; every used operation is injected.
@MainActor
final class LoadingTests: XCTestCase {
    private func today() -> TodayMetrics {
        TodayMetrics(actual_today: 25, target_today: 100, month_goal: nil,
                     remaining: 75, pct: 25, updated_at: "2026-11-02T12:00:00Z",
                     data_delayed: false, warning: nil)
    }

    private func month() -> MonthMetrics {
        MonthMetrics(month: "2026-11", month_goal: 1000, mtd_actual: 25, mtd_target: 100,
                     ahead_behind: -75, days: [], updated_at: "2026-11-02T12:00:00Z",
                     data_delayed: false, warning: nil)
    }

    private func stock(status: String = "fresh", seller: String? = "shared") -> StockSummaryResponse {
        StockSummaryResponse(schemaVersion: 1, status: status, complete: status == "fresh",
                             sellerId: seller, lastSuccessAt: "2026-11-02T12:00:00Z",
                             sourceObservedAt: "2026-11-02T12:00:00Z", url: "https://synthetic.invalid",
                             data: status == "fresh" ? StockCounts(drafts: 3, active: 8, reserved: 1,
                                 pendingManual: 2, doubleSales: 0, failedListings: 4, openQuestions: 5) : nil)
    }

    func testStockDoesNotBlockTodayAndFailureIsIndependent() async {
        let gate = Gate<StockSummaryResponse>()
        let visible = expectation(description: "Sales visible before stock")
        let vm = TodayViewModel(usesCache: false, fetchStock: { try await gate.wait() },
                                fetchToday: { self.today() }, fetchMonth: { self.month() })
        let observation = vm.$data.compactMap { $0 }.prefix(1).sink { _ in visible.fulfill() }
        let task = Task { await vm.load() }
        await fulfillment(of: [visible], timeout: 1)
        XCTAssertEqual(vm.data?.actual_today, 25)
        XCTAssertNil(vm.stockSummary)
        await gate.fail()
        await task.value
        XCTAssertNil(vm.errorText)
        XCTAssertNotNil(vm.stockErrorText)
        XCTAssertFalse(vm.isLoadingStock)
        withExtendedLifetime(observation) {}
    }

    func testStockOutageRetainsTimestampButRevocationAndScopeChangeDiscardData() async {
        var next = stock()
        let vm = TodayViewModel(usesCache: false, fetchStock: { next },
                                fetchToday: { self.today() }, fetchMonth: { self.month() })
        await vm.load()
        XCTAssertEqual(vm.stockSummary?.data?.active, 8)
        next = stock(status: "unavailable")
        await vm.load()
        XCTAssertEqual(vm.stockSummary?.lastSuccessAt, "2026-11-02T12:00:00Z")
        XCTAssertNotNil(vm.stockErrorText)
        next = stock(status: "unauthorized")
        await vm.load()
        XCTAssertNil(vm.stockSummary)
        next = stock()
        await vm.load()
        next = stock(status: "unavailable", seller: "other")
        await vm.load()
        XCTAssertNil(vm.stockSummary)
    }

    func testDisabledStockIsHiddenAndFetchIsOptional() async {
        let disabled = TodayViewModel(usesCache: false, fetchStock: { self.stock(status: "disabled", seller: nil) },
                                      fetchToday: { self.today() }, fetchMonth: { self.month() })
        await disabled.load()
        XCTAssertFalse(disabled.showsStockSummary)
        XCTAssertNil(disabled.stockSummary)
        XCTAssertNil(disabled.stockErrorText)
        let absent = TodayViewModel(usesCache: false, fetchStock: nil,
                                    fetchToday: { self.today() }, fetchMonth: { self.month() })
        await absent.load()
        XCTAssertFalse(absent.showsStockSummary)
        XCTAssertEqual(absent.data?.actual_today, 25)
    }

    func testTodayAppearsBeforeSlowWeekAndSurvivesItsFailure() async {
        let gate = Gate<MonthMetrics>()
        let visible = expectation(description: "Today visible while week is pending")
        let vm = TodayViewModel(usesCache: false, fetchToday: { self.today() }, fetchMonth: { try await gate.wait() })
        let observation = vm.$data.compactMap { $0 }.prefix(1).sink { _ in visible.fulfill() }
        let task = Task { await vm.load() }
        await fulfillment(of: [visible], timeout: 1)
        XCTAssertEqual(vm.data?.actual_today, 25)
        await gate.fail()
        await task.value
        XCTAssertEqual(vm.data?.actual_today, 25)
        XCTAssertNil(vm.errorText)
        XCTAssertNotNil(vm.weekErrorText)
        XCTAssertFalse(vm.isLoadingToday)
        withExtendedLifetime(observation) {}
    }

    func testConcurrentRefreshesShareWorkAndFailureCanRecover() async {
        let gate = Gate<TodayMetrics>()
        var calls = 0
        let vm = TodayViewModel(usesCache: false, fetchToday: {
            calls += 1
            if calls == 1 { return try await gate.wait() }
            return self.today()
        }, fetchMonth: { self.month() })
        let a = Task { await vm.load() }
        let b = Task { await vm.load() }
        await gate.waitUntilStarted()
        // Both main-actor tasks have entered load before resolving the flight.
        await Task.yield()
        await gate.fail()
        await a.value
        await b.value
        XCTAssertEqual(calls, 1)
        XCTAssertNil(vm.data)
        XCTAssertNotNil(vm.errorText)
        await vm.load()
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(vm.data?.actual_today, 25)
        XCTAssertNil(vm.errorText)
    }

    func testCurrentMonthDoesNotWaitForPreviousMonth() async {
        let gate = Gate<MonthMetrics>()
        let visible = expectation(description: "Current month visible")
        let vm = MonthViewModel(usesCache: false, fetchMonth: { key in
            if key != nil { return try await gate.wait() }
            return self.month()
        })
        let observation = vm.$data.compactMap { $0 }.prefix(1).sink { _ in visible.fulfill() }
        let task = Task { await vm.load() }
        await fulfillment(of: [visible], timeout: 1)
        XCTAssertEqual(vm.monthGoal, 1000)
        await gate.fail()
        await task.value
        XCTAssertEqual(vm.data?.mtd_actual, 25)
        XCTAssertNotNil(vm.lastMonthErrorText)
        withExtendedLifetime(observation) {}
    }

    func testFailedSaveReturnsFailureAndDoesNotClaimSuccess() async {
        let vm = TodayViewModel(usesCache: false, fetchToday: { self.today() }, fetchMonth: { self.month() },
                                saveEntry: { _, _, _, _, _ in throw URLError(.notConnectedToInternet) })
        let saved = await vm.addManualEntry(amount: 20, source: .cash, description: nil, note: "keep me")
        XCTAssertFalse(saved)
        XCTAssertTrue(vm.manualEntryFailed)
        XCTAssertFalse(vm.isSavingManualEntry)
    }
}

private actor Gate<Value> {
    private var continuation: CheckedContinuation<Value, Error>?
    func wait() async throws -> Value {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func waitUntilStarted() async {
        while continuation == nil { await Task.yield() }
    }
    func fail() async {
        await waitUntilStarted()
        continuation?.resume(throwing: URLError(.timedOut))
        continuation = nil
    }
}
