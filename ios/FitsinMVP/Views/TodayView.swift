import SwiftUI

struct TodayView: View {
    @ObservedObject var vm: TodayViewModel
    @ObservedObject var rotaVM: RotaViewModel
    @EnvironmentObject var session: AppSession
    @Environment(\.scenePhase) private var scenePhase
    @State private var animateIn = false
    @State private var animatedProgress = 0.0
    @State private var selectedSource: ManualSource = .cash
    @State private var manualAmount = ""
    @State private var manualNote = ""
    @State private var manualDescription = ""
    @State private var manualDate = Date()
    @State private var showManualEntry = false
    @State private var showSchedule = false
    @FocusState private var amountFocused: Bool

    private static let manualDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private static let gbpFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "GBP"
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private static let dayNumFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private var londonCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return cal
    }

    private var isSundayToday: Bool {
        londonCalendar.component(.weekday, from: Date()) == 1
    }

    private var progressTone: Color {
        guard let data = vm.data else { return BrandTheme.accent }
        if isSundayToday { return BrandTheme.danger }
        return data.pct >= 100 ? BrandTheme.success : BrandTheme.ink
    }

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
                        } else if vm.isLoadingToday || vm.errorText == nil {
                            ProgressView("Loading Today…")
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            Button("Retry Today") { Task { await vm.load() } }
                                .padding()
                        }

                        notices
                        weekSection
                        rotaSection
                        manualEntrySection
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 16)
                }
                .refreshable { await vm.load() }
            }
            .task {
                vm.loadCached()
                // Fade the content (spinner or cached data) in immediately so the
                // loading state is visible while the network fetch is in flight.
                animateIn = false
                withAnimation(.easeOut(duration: 0.4)) {
                    animateIn = true
                }
                let userName = session.userName ?? ""
                async let loadToday: Void = vm.load()
                async let loadRota: Void = rotaVM.load()
                async let loadSched: Void = rotaVM.loadSchedule(userName: userName)
                _ = await (loadToday, loadRota, loadSched)
                if !Task.isCancelled && scenePhase == .active { vm.startAutoRefresh(intervalSeconds: 60) }
            }
            .onDisappear { vm.stopAutoRefresh() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Today")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandTheme.ink)
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }

    // MARK: - Hero

    private func heroSection(data: TodayMetrics) -> some View {
        let progress = isSundayToday ? 0.0 : min(max(data.pct / 100.0, 0), 1)

        return VStack(spacing: 8) {
            Text(isSundayToday ? "CLOSED" : "TODAY'S SALES")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(BrandTheme.inkSoft)

            Text(isSundayToday ? "Sunday" : gbp(data.actual_today))
                .font(.system(size: 46, weight: .black, design: .rounded))
                .foregroundStyle(isSundayToday ? BrandTheme.danger : BrandTheme.ink)

            if !isSundayToday {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(BrandTheme.ink.opacity(0.06))
                            .frame(height: 5)
                        Capsule()
                            .fill(progressTone)
                            .frame(width: max(4, geo.size.width * animatedProgress), height: 5)
                    }
                }
                .frame(height: 5)
                .padding(.horizontal, 40)

                HStack(spacing: 4) {
                    Text("\(Int(data.pct))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandTheme.ink)
                    Text("of target")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.inkSoft)
                    Text("·")
                        .foregroundStyle(BrandTheme.inkSoft)
                    Text(formatTimestamp(data.updated_at))
                        .font(.caption)
                        .foregroundStyle(BrandTheme.inkSoft)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .onAppear {
            animatedProgress = 0
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: data.pct) { _, newValue in
            withAnimation(.easeOut(duration: 0.4)) {
                animatedProgress = isSundayToday ? 0 : min(max(newValue / 100.0, 0), 1)
            }
        }
    }

    // MARK: - Stats Row

    private func statsRow(data: TodayMetrics) -> some View {
        let isOver = data.remaining < 0

        return HStack(spacing: 0) {
            statItem(
                label: "TARGET",
                value: isSundayToday ? "—" : gbp(data.target_today),
                tone: BrandTheme.ink
            )

            Divider()
                .frame(height: 32)
                .overlay(BrandTheme.divider)

            statItem(
                label: isOver ? "OVER BY" : "REMAINING",
                value: isSundayToday ? "—" : gbp(isOver ? abs(data.remaining) : data.remaining),
                tone: isSundayToday ? BrandTheme.inkSoft : (isOver ? BrandTheme.success : BrandTheme.ink)
            )

            Divider()
                .frame(height: 32)
                .overlay(BrandTheme.divider)

            statItem(
                label: "MONTH GOAL",
                value: data.month_goal != nil ? gbp(data.month_goal!) : "—",
                tone: BrandTheme.inkSoft
            )
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

    // MARK: - Week

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("This Week")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(0.3)
                .foregroundStyle(BrandTheme.ink)
                .padding(.horizontal, 20)

            if vm.isLoadingWeek { ProgressView("Refreshing week…").padding(.horizontal, 20) }
            if let error = vm.weekErrorText {
                InlineNotice(text: error, tone: BrandTheme.danger, systemImage: "wifi.exclamationmark")
                    .padding(.horizontal, 20)
            }
            if let updated = vm.weekUpdatedAt {
                Text("Week updated \(formatTimestamp(updated))")
                    .font(.caption).foregroundStyle(BrandTheme.inkSoft).padding(.horizontal, 20)
            }
            if vm.weekAhead.isEmpty && !vm.isLoadingWeek && vm.weekErrorText == nil {
                Text("No upcoming days available.").font(.caption).padding(.horizontal, 20)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.weekAhead) { day in
                        let isSunday = londonCalendar.component(.weekday, from: day.date) == 1
                        let isToday = londonCalendar.isDateInToday(day.date)
                        let hitTarget = !isSunday && day.actual >= day.target && day.target > 0

                        VStack(spacing: 6) {
                            Text(Self.dayFormatter.string(from: day.date).uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(0.5)
                                .foregroundStyle(isToday ? BrandTheme.ink : BrandTheme.inkSoft)

                            Text(Self.dayNumFormatter.string(from: day.date))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(isSunday ? BrandTheme.danger.opacity(0.5) : BrandTheme.ink)

                            if isSunday {
                                Text("—")
                                    .font(.caption2)
                                    .foregroundStyle(BrandTheme.inkSoft)
                            } else {
                                Text(gbp(day.target))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(hitTarget ? BrandTheme.success : BrandTheme.inkSoft)
                            }
                        }
                        .frame(width: 64)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isToday ? BrandTheme.ink.opacity(0.04) : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isToday ? BrandTheme.ink.opacity(0.12) : .clear, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Rota

    private static let rotaDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private var rotaSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Who's Opening?")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(0.3)
                    .foregroundStyle(BrandTheme.ink)
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        showSchedule.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption)
                        Text("My Days")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(BrandTheme.ink.opacity(0.06)))
                    .foregroundStyle(BrandTheme.ink)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            if showSchedule {
                scheduleRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            VStack(spacing: 0) {
                ForEach(Array(rotaVM.upcomingDays.enumerated()), id: \.element.key) { index, day in
                    if index > 0 {
                        Divider().overlay(BrandTheme.divider).padding(.horizontal, 20)
                    }
                    rotaDayRow(date: day.date, key: day.key)
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

    private var scheduleRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("I can open every:")
                .font(.caption)
                .foregroundStyle(BrandTheme.inkSoft)

            HStack(spacing: 6) {
                ForEach(RotaViewModel.weekdayLabels, id: \.id) { day in
                    let isSelected = rotaVM.myScheduleDays.contains(day.id)
                    Button {
                        var updated = rotaVM.myScheduleDays
                        if isSelected { updated.remove(day.id) } else { updated.insert(day.id) }
                        Task { await rotaVM.saveSchedule(userName: session.userName ?? "", days: updated) }
                    } label: {
                        Text(day.short)
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? BrandTheme.ink : BrandTheme.ink.opacity(0.04))
                            )
                            .foregroundStyle(isSelected ? .white : BrandTheme.inkSoft)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Auto-fills each week. Tap days above to override.")
                .font(.system(size: 10))
                .foregroundStyle(BrandTheme.inkSoft.opacity(0.6))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func rotaDayRow(date: Date, key: String) -> some View {
        let people = rotaVM.entries(for: key)
        let userName = session.userName ?? ""
        let isMeSignedUp = rotaVM.isSignedUp(for: key, userName: userName)
        let isToday = londonCalendar.isDateInToday(date)

        return Button {
            Task { await rotaVM.toggle(dateKey: key, userName: userName) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(Self.rotaDayFormatter.string(from: date))
                        .font(.system(size: 13, weight: isToday ? .bold : .semibold))
                        .foregroundStyle(BrandTheme.ink)
                    if isToday {
                        Text("Today")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(BrandTheme.inkSoft)
                    }
                }
                .frame(width: 90, alignment: .leading)

                if people.isEmpty {
                    Text("No one yet")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.inkSoft.opacity(0.5))
                } else {
                    HStack(spacing: 6) {
                        ForEach(people) { person in
                            Text(person.name)
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(person.name.lowercased() == userName.lowercased()
                                              ? BrandTheme.ink
                                              : BrandTheme.ink.opacity(0.08))
                                )
                                .foregroundStyle(person.name.lowercased() == userName.lowercased()
                                                 ? .white
                                                 : BrandTheme.ink)
                        }
                    }
                }

                Spacer()

                Image(systemName: isMeSignedUp ? "checkmark.circle.fill" : "plus.circle")
                    .font(.body)
                    .foregroundStyle(isMeSignedUp ? BrandTheme.success : BrandTheme.inkSoft.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Manual Entry

    private var manualEntrySection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    showManualEntry.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                    Text("Log Sale")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("Vinted / Cash / Other")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.inkSoft)
                    Image(systemName: showManualEntry ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandTheme.inkSoft)
                }
                .foregroundStyle(BrandTheme.ink)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            if showManualEntry {
                manualEntryForm
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
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

    private var manualEntryForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(ManualSource.allCases) { source in
                    Button(source.label) {
                        selectedSource = source
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(selectedSource == source ? BrandTheme.ink : BrandTheme.ink.opacity(0.06))
                    )
                    .foregroundStyle(selectedSource == source ? .white : BrandTheme.inkSoft)
                }
            }

            TextField("Amount (GBP)", text: $manualAmount)
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
                .textFieldStyle(FitsinInputStyle())
                .focused($amountFocused)

            HStack {
                Text("Date of sale")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BrandTheme.inkSoft)
                Spacer()
                DatePicker(
                    "",
                    selection: $manualDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }

            if !Calendar.current.isDateInToday(manualDate) {
                Text("Backdated — counts toward \(Self.manualDateFormatter.string(from: manualDate))")
                    .font(.caption2)
                    .foregroundStyle(BrandTheme.accent)
            }

            if selectedSource == .other {
                TextField("Brief description", text: $manualDescription)
                    .textInputAutocapitalization(.sentences)
                    .textFieldStyle(FitsinInputStyle())
            }

            TextField("Note (optional)", text: $manualNote)
                .textInputAutocapitalization(.sentences)
                .textFieldStyle(FitsinInputStyle())

            Button {
                guard let amount = parseAmount(manualAmount) else { return }
                let description = selectedSource == .other ? manualDescription.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                let dateString = Self.manualDateFormatter.string(from: manualDate)
                Task {
                    let saved = await vm.addManualEntry(
                        amount: amount,
                        source: selectedSource,
                        description: description?.isEmpty == true ? nil : description,
                        note: manualNote.trimmingCharacters(in: .whitespacesAndNewlines),
                        date: dateString
                    )
                    guard saved else { return }
                    // Clear only the per-sale fields; keep source + date so a run
                    // of same-day sales can be logged rapidly. Refocus the amount.
                    manualAmount = ""
                    manualNote = ""
                    manualDescription = ""
                    amountFocused = true
                }
            } label: {
                HStack {
                    if vm.isSavingManualEntry {
                        ProgressView().tint(.white)
                    }
                    Text(vm.isSavingManualEntry ? "Saving..." : "Save Sale")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(canSaveManual ? BrandTheme.ink : BrandTheme.ink.opacity(0.3))
                )
                .foregroundStyle(.white)
            }
            .disabled(!canSaveManual || vm.isSavingManualEntry)
        }
    }

    // MARK: - Notices

    private var notices: some View {
        VStack(spacing: 8) {
            if let error = vm.errorText {
                InlineNotice(text: error, tone: BrandTheme.danger, systemImage: "wifi.exclamationmark")
            }
            if let status = vm.manualEntryStatus {
                InlineNotice(text: status, tone: vm.manualEntryFailed ? BrandTheme.danger : BrandTheme.success, systemImage: vm.manualEntryFailed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private var canSaveManual: Bool {
        guard parseAmount(manualAmount) != nil else { return false }
        if selectedSource == .other {
            return !manualDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func parseAmount(_ raw: String) -> Double? {
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    private func formatTimestamp(_ raw: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(identifier: "Europe/London")

        if let date = parser.date(from: raw) ?? fallback.date(from: raw) {
            return formatter.string(from: date)
        }
        return "-"
    }
}

struct FitsinInputStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundStyle(BrandTheme.ink)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BrandTheme.outline, lineWidth: 1)
            )
    }
}
