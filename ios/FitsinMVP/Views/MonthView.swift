import SwiftUI

struct MonthView: View {
    @ObservedObject var vm: MonthViewModel
    @State private var showingGoalSheet = false
    @State private var showingProjectionCalendar = false
    @State private var goalInput = ""
    @Environment(\.scenePhase) private var scenePhase
    @State private var animateIn = false

    private static let gbpFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "GBP"
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private static let dayParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private static let displayDayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private func gbp(_ value: Double) -> String {
        Self.gbpFormatter.string(from: NSNumber(value: value)) ?? "£0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView {
                    VStack(spacing: 0) {
                        if let data = vm.data {
                            heroSection(data: data)
                            statsRow(data: data)
                            actionsRow
                            recentDaysSection(data: data, lastMonthData: vm.lastMonthData)

                            Spacer().frame(height: 20)

                            lastMonthCard(data: vm.lastMonthData)

                            Spacer().frame(height: 20)

                            historyLink
                        } else if vm.isLoading || vm.errorText == nil {
                            ProgressView("Loading month…")
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            Button("Retry month") { Task { await vm.load() } }.padding()
                        }

                        notices
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 16)
                }
                .refreshable { await vm.load() }
            }
            .task {
                vm.loadCached()
                animateIn = false
                withAnimation(.easeOut(duration: 0.4)) {
                    animateIn = true
                }
                await vm.load()
                if !Task.isCancelled && scenePhase == .active { vm.startAutoRefresh(intervalSeconds: 60) }
            }
            .onDisappear { vm.stopAutoRefresh() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Month")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandTheme.ink)
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
            .sheet(isPresented: $showingGoalSheet) { goalSheet }
            .sheet(isPresented: $showingProjectionCalendar) { projectionCalendarSheet }
        }
    }

    // MARK: - Hero

    private func heroSection(data: MonthMetrics) -> some View {
        let paceTone = data.ahead_behind >= 0 ? BrandTheme.success : BrandTheme.danger
        let achieved = min(max(data.mtd_actual / max(data.mtd_target, 1), 0), 1)

        return VStack(spacing: 8) {
            Text("MONTH TO DATE")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(BrandTheme.inkSoft)

            Text(gbp(data.mtd_actual))
                .font(.system(size: 46, weight: .black, design: .rounded))
                .foregroundStyle(BrandTheme.ink)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(BrandTheme.ink.opacity(0.06))
                        .frame(height: 5)
                    Capsule()
                        .fill(paceTone)
                        .frame(width: max(4, geo.size.width * achieved), height: 5)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 40)

            HStack(spacing: 4) {
                Text("\(Int(achieved * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.ink)
                Text("of target")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.inkSoft)
                Text("·")
                    .foregroundStyle(BrandTheme.inkSoft)
                StatusPill(
                    text: data.ahead_behind >= 0 ? "Ahead" : "Behind",
                    tone: paceTone
                )
            }

            Text(formatTimestamp(data.updated_at))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(BrandTheme.inkSoft.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
    }

    // MARK: - Stats Row

    private func statsRow(data: MonthMetrics) -> some View {
        let projection = totalMonthProjection(from: data)
        let gapTone = data.ahead_behind >= 0 ? BrandTheme.success : BrandTheme.danger

        return HStack(spacing: 0) {
            statItem(label: "TARGET", value: gbp(data.mtd_target), tone: BrandTheme.ink)
            Divider().frame(height: 32).overlay(BrandTheme.divider)
            statItem(label: "GAP", value: gbp(abs(data.ahead_behind)), tone: gapTone)
            Divider().frame(height: 32).overlay(BrandTheme.divider)
            statItem(label: "PROJECTION", value: gbp(projection), tone: BrandTheme.inkSoft)
        }
        .padding(.vertical, 18)
        .background(BrandTheme.surfaceStrong)
        .overlay(
            VStack {
                Divider().overlay(BrandTheme.outline)
                Spacer()
                Divider().overlay(BrandTheme.outline)
            }
        )
    }

    private func statItem(label: String, value: String, tone: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(BrandTheme.inkSoft)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private var actionsRow: some View {
        HStack(spacing: 0) {
            Button {
                if let goal = vm.monthGoal {
                    goalInput = String(format: "%.2f", goal)
                } else {
                    goalInput = ""
                }
                showingGoalSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.caption)
                    Text("Goal: \(vm.monthGoal != nil ? gbp(vm.monthGoal!) : "Not set")")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(BrandTheme.ink)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 20).overlay(BrandTheme.divider)

            Button {
                showingProjectionCalendar = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text("Forecast")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(BrandTheme.ink)
            }
            .buttonStyle(.plain)
        }
        .background(BrandTheme.surfaceStrong)
        .overlay(
            VStack {
                Spacer()
                Divider().overlay(BrandTheme.outline)
            }
        )
    }

    // MARK: - Recent Days

    private func recentDaysSection(data: MonthMetrics, lastMonthData: MonthMetrics?) -> some View {
        let currentDays = filteredDays(from: data)
        let lastMonthDays = lastMonthRecentDays(currentData: data, lastMonthData: lastMonthData)
        let allDays = Array((lastMonthDays + currentDays).reversed())

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent Days")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(0.3)
                    .foregroundStyle(BrandTheme.ink)
                Spacer()
                Text("\(allDays.count) days")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.inkSoft)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            if allDays.isEmpty {
                Text("No completed days yet.")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.inkSoft)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allDays.enumerated()), id: \.element.id) { index, day in
                        if index > 0 {
                            Divider().overlay(BrandTheme.divider).padding(.horizontal, 20)
                        }

                        let sunday = isSunday(day.date)
                        let isPrevMonth = isLastMonth(day.date)

                        if sunday {
                            HStack(spacing: 10) {
                                Text(displayDate(day.date))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(BrandTheme.inkSoft)
                                    .frame(width: 90, alignment: .leading)
                                Spacer()
                                Text("Closed")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(BrandTheme.danger)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        } else {
                            NavigationLink {
                                DaySalesView(date: day.date)
                            } label: {
                                HStack(spacing: 10) {
                                    Text(displayDate(day.date))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(isPrevMonth ? BrandTheme.inkSoft : BrandTheme.ink)
                                        .frame(width: 90, alignment: .leading)

                                    Spacer()
                                    Text(gbp(day.actual))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(isPrevMonth ? BrandTheme.inkSoft : BrandTheme.ink)
                                    Text("/ \(gbp(day.target))")
                                        .font(.system(size: 11))
                                        .foregroundStyle(BrandTheme.inkSoft)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(BrandTheme.inkSoft.opacity(0.4))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
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
        .padding(.top, 16)
    }

    // MARK: - Last Month Card

    private func lastMonthCard(data lastMonth: MonthMetrics?) -> some View {
        Group {
            if let last = lastMonth {
                let paceTone = last.ahead_behind >= 0 ? BrandTheme.success : BrandTheme.danger

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Last Month")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(0.3)
                            .foregroundStyle(BrandTheme.ink)
                        Spacer()
                        StatusPill(
                            text: last.ahead_behind >= 0 ? "Hit target" : "Missed",
                            tone: paceTone
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 14)

                    HStack(spacing: 0) {
                        statItem(label: "ACTUAL", value: gbp(last.mtd_actual), tone: BrandTheme.ink)
                        Divider().frame(height: 32).overlay(BrandTheme.divider)
                        statItem(label: "TARGET", value: gbp(last.mtd_target), tone: BrandTheme.inkSoft)
                        Divider().frame(height: 32).overlay(BrandTheme.divider)
                        statItem(label: "GAP", value: gbp(abs(last.ahead_behind)), tone: paceTone)
                    }
                    .padding(.bottom, 20)
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
        }
    }

    // MARK: - History Link

    private var historyLink: some View {
        NavigationLink {
            MonthHistoryView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.body.weight(.semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("View History")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BrandTheme.ink)
                    Text("Past months and year-by-year")
                        .font(.system(size: 11))
                        .foregroundStyle(BrandTheme.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(BrandTheme.inkSoft.opacity(0.4))
            }
            .foregroundStyle(BrandTheme.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .background(BrandTheme.surfaceStrong)
        .overlay(
            VStack {
                Spacer()
                Divider().overlay(BrandTheme.outline)
            }
        )
    }

    // MARK: - Notices

    private var notices: some View {
        VStack(spacing: 8) {
            if let error = vm.lastMonthErrorText {
                InlineNotice(text: error, tone: BrandTheme.danger, systemImage: "wifi.exclamationmark")
            }
            if let error = vm.errorText {
                InlineNotice(text: error, tone: BrandTheme.danger, systemImage: "wifi.exclamationmark")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Sheets

    private var goalSheet: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Monthly Goal")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(BrandTheme.ink)
                        Text("Remaining daily targets rebalance to hit this number.")
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("e.g. 4000", text: $goalInput)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(FitsinInputStyle())

                    Button {
                        let parsed = Double(goalInput.replacingOccurrences(of: ",", with: "."))
                        Task {
                            await vm.saveMonthGoal(parsed)
                            showingGoalSheet = false
                        }
                    } label: {
                        HStack {
                            if vm.isSavingGoal { ProgressView().tint(.white) }
                            Text(vm.isSavingGoal ? "Saving..." : "Save Goal")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(BrandTheme.ink)
                        )
                        .foregroundStyle(.white)
                    }
                    .disabled(vm.isSavingGoal)

                    Button("Clear Goal") {
                        Task {
                            await vm.saveMonthGoal(nil)
                            showingGoalSheet = false
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.danger)
                }
                .padding(20)
                .vintageCard()
                .padding(20)
            }
            .navigationTitle("Set Goal")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingGoalSheet = false }
                }
            }
        }
    }

    private var projectionCalendarSheet: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView {
                    VStack(spacing: 0) {
                        if let data = vm.data {
                            ForEach(remainingDays(from: data), id: \.id) { day in
                                let sunday = isSunday(day.date)
                                HStack {
                                    Text(displayDate(day.date))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(BrandTheme.ink)
                                    Spacer()
                                    if sunday {
                                        Text("Closed")
                                            .font(.caption)
                                            .foregroundStyle(BrandTheme.danger)
                                    } else {
                                        Text(gbp(day.target))
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(BrandTheme.ink)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 11)

                                Divider().overlay(BrandTheme.divider).padding(.horizontal, 20)
                            }
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 200)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Forecast")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingProjectionCalendar = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func lastMonthRecentDays(currentData: MonthMetrics, lastMonthData: MonthMetrics?) -> [MonthDay] {
        guard let lastData = lastMonthData else { return [] }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let today = cal.startOfDay(for: Date())

        let currentMonthDayCount = filteredDays(from: currentData).count
        let fillCount = max(0, 7 - currentMonthDayCount)
        guard fillCount > 0 else { return [] }

        return lastData.days
            .filter { day in
                guard let date = Self.dayParser.date(from: day.date) else { return false }
                return cal.startOfDay(for: date) < today
            }
            .suffix(fillCount)
            .map { $0 }
    }

    private func isLastMonth(_ dateStr: String) -> Bool {
        guard let date = Self.dayParser.date(from: dateStr) else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return cal.component(.month, from: date) != cal.component(.month, from: Date())
    }

    private func filteredDays(from data: MonthMetrics) -> [MonthDay] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let today = cal.startOfDay(for: Date())
        return data.days.filter { day in
            guard let date = Self.dayParser.date(from: day.date) else { return false }
            return cal.startOfDay(for: date) <= today
        }
    }

    private func remainingDays(from data: MonthMetrics) -> [MonthDay] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let today = cal.startOfDay(for: Date())
        return data.days.filter { day in
            guard let date = Self.dayParser.date(from: day.date) else { return false }
            return cal.startOfDay(for: date) >= today
        }
    }

    private func isSunday(_ day: String) -> Bool {
        guard let date = Self.dayParser.date(from: day) else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return cal.component(.weekday, from: date) == 1
    }

    private func totalMonthProjection(from data: MonthMetrics) -> Double {
        data.days.filter { !isSunday($0.date) }.reduce(0) { $0 + $1.target }
    }

    private func displayDate(_ raw: String) -> String {
        guard let date = Self.dayParser.date(from: raw) else { return raw }
        return Self.displayDayFmt.string(from: date)
    }

    private func formatTimestamp(_ raw: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        if let date = parser.date(from: raw) ?? fallback.date(from: raw) {
            return formatter.string(from: date)
        }
        return "-"
    }
}
