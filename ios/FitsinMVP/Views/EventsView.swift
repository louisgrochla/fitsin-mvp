import SwiftUI

struct EventsView: View {
    @ObservedObject var vm: EventsViewModel
    @EnvironmentObject var calendarAuth: CalendarAuthManager
    @State private var showAddEvent = false
    @State private var animateIn = false

    private let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private static let dayHeaderFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE d MMMM"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView {
                    VStack(spacing: 0) {
                        if calendarAuth.isSignedIn {
                            monthHeader
                            calendarGrid
                            dayEventsSection
                        } else {
                            connectPrompt
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Events")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandTheme.ink)
                }
                if calendarAuth.isSignedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddEvent = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(BrandTheme.ink)
                        }
                    }
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
            .task {
                vm.loadCached()
                animateIn = false
                withAnimation(.easeOut(duration: 0.4)) {
                    animateIn = true
                }
                await vm.load()
            }
            .sheet(isPresented: $showAddEvent) {
                AddEventView(selectedDate: vm.selectedDate ?? Date()) { _ in
                    Task { await vm.load() }
                }
            }
        }
    }

    // MARK: - Connect Prompt

    private var connectPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(BrandTheme.inkSoft)

            Text("Connect Google Calendar")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(BrandTheme.ink)

            Text("Sign in to see and manage your shared store calendar")
                .font(.caption)
                .foregroundStyle(BrandTheme.inkSoft)
                .multilineTextAlignment(.center)

            Button {
                Task { try? await calendarAuth.signIn() }
            } label: {
                Text("Sign in with Google")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(BrandTheme.ink)
                    )
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button { vm.goToPreviousMonth() } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BrandTheme.ink)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(vm.monthTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(BrandTheme.ink)
            }

            Spacer()

            Button { vm.goToToday() } label: {
                Text("Today")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(BrandTheme.ink.opacity(0.06)))
                    .foregroundStyle(BrandTheme.ink)
            }

            Button { vm.goToNextMonth() } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BrandTheme.ink)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 4) {
            // Weekday header
            LazyVGrid(columns: gridColumns, spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandTheme.inkSoft)
                        .frame(height: 28)
                }
            }

            // Day cells
            LazyVGrid(columns: gridColumns, spacing: 4) {
                ForEach(Array(vm.daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func dayCell(_ date: Date) -> some View {
        let isToday = vm.isToday(date)
        let isSelected = vm.isSelected(date)
        let hasEvents = vm.hasEvents(date)

        return Button {
            vm.selectDay(date)
        } label: {
            VStack(spacing: 2) {
                let cal = Calendar(identifier: .gregorian)
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 15, weight: isToday || isSelected ? .bold : .regular))
                    .foregroundStyle(
                        isToday || isSelected ? .white :
                            BrandTheme.ink
                    )

                Circle()
                    .fill(hasEvents && !isSelected && !isToday ? BrandTheme.accent : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 36, height: 44)
            .background(
                Circle()
                    .fill(
                        isToday ? BrandTheme.ink :
                            isSelected ? BrandTheme.accent :
                            .clear
                    )
                    .frame(width: 36, height: 36)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day Events

    private var dayEventsSection: some View {
        Group {
            if let selected = vm.selectedDate {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(Self.dayHeaderFmt.string(from: selected))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(0.3)
                            .foregroundStyle(BrandTheme.ink)
                        Spacer()
                        Text("\(vm.eventsForSelectedDay.count) events")
                            .font(.caption)
                            .foregroundStyle(BrandTheme.inkSoft)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                    if vm.eventsForSelectedDay.isEmpty {
                        Text("No events on this day")
                            .font(.caption)
                            .foregroundStyle(BrandTheme.inkSoft)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(vm.eventsForSelectedDay.enumerated()), id: \.element.id) { index, event in
                                if index > 0 {
                                    Divider().overlay(BrandTheme.divider).padding(.horizontal, 20)
                                }

                                NavigationLink {
                                    EventDetailView(eventId: event.id, fallbackEvent: event)
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(event.title)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(BrandTheme.ink)
                                                .lineLimit(1)

                                            HStack(spacing: 6) {
                                                if event.isAllDay {
                                                    Text("All day")
                                                        .font(.system(size: 11))
                                                        .foregroundStyle(BrandTheme.inkSoft)
                                                } else if let start = event.startDate {
                                                    Text(Self.timeFmt.string(from: start))
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundStyle(BrandTheme.inkSoft)
                                                    if let end = event.endDate {
                                                        Text("– \(Self.timeFmt.string(from: end))")
                                                            .font(.system(size: 11))
                                                            .foregroundStyle(BrandTheme.inkSoft)
                                                    }
                                                }

                                                if let loc = event.location, !loc.isEmpty {
                                                    Text("· \(loc)")
                                                        .font(.system(size: 11))
                                                        .foregroundStyle(BrandTheme.inkSoft)
                                                        .lineLimit(1)
                                                }
                                            }
                                        }

                                        Spacer()

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
                .background(BrandTheme.surfaceStrong)
                .overlay(
                    VStack {
                        Divider().overlay(BrandTheme.outline)
                        Spacer()
                        Divider().overlay(BrandTheme.outline)
                    }
                )
                .padding(.top, 8)
            }
        }
    }
}
