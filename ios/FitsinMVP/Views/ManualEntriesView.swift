import SwiftUI

struct ManualEntriesView: View {
    @StateObject private var vm = ManualEntriesViewModel()
    @State private var selectedSource: ManualSource?
    @State private var animateIn = false
    @State private var pendingDeleteEntry: ManualEntry?

    private var gbp: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "GBP"
        f.locale = Locale(identifier: "en_GB")
        return f
    }

    private static let isoDayParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private static let friendlyDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private func friendlyDate(_ iso: String) -> String {
        if let date = Self.isoDayParser.date(from: iso) {
            return Self.friendlyDay.string(from: date)
        }
        return iso
    }

    private var filteredEntries: [ManualEntry] {
        guard let selectedSource else { return vm.entries }
        return vm.entries.filter { $0.source == selectedSource }
    }

    private var totalAmount: Double {
        filteredEntries.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ZStack {
            DashboardBackground()

            ScrollView {
                VStack(spacing: 18) {
                    headerCard

                    DashboardSection(title: "Filter", subtitle: "Source channel") {
                        sourceFilters
                            .vintageCard()
                    }

                    DashboardSection(title: "Entries", subtitle: "Latest manual sales") {
                        if filteredEntries.isEmpty {
                            Text("No manual entries for this month yet.")
                                .foregroundStyle(BrandTheme.inkSoft)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .vintageCard()
                        } else {
                            VStack(spacing: 8) {
                ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                    entryRow(entry)
                                        .opacity(animateIn ? 1 : 0)
                                        .offset(y: animateIn ? 0 : 10)
                                        .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.02), value: animateIn)
                                }
                            }
                            .vintageCard()
                        }
                    }

                    if let errorText = vm.errorText {
                        InlineNotice(text: errorText, tone: BrandTheme.danger, systemImage: "wifi.exclamationmark")
                            .vintageCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 8)
            }
        }
        .navigationTitle("Manual Entries")
        .refreshable { await vm.load() }
        .task {
            animateIn = false
            withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
                animateIn = true
            }
            await vm.load()
            vm.startAutoRefresh(intervalSeconds: 60)
        }
        .onDisappear { vm.stopAutoRefresh() }
        .alert("Delete entry?", isPresented: Binding(
            get: { pendingDeleteEntry != nil },
            set: { if !$0 { pendingDeleteEntry = nil } }
        )) {
            Button("Delete", role: .destructive) {
                guard let entry = pendingDeleteEntry else { return }
                pendingDeleteEntry = nil
                Task { await vm.deleteEntry(entry) }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteEntry = nil
            }
        } message: {
            Text("This will remove the manual sale entry from all devices.")
        }
    }

    private var headerCard: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Manual Sales")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.inkSoft)
                Text(gbp.string(from: NSNumber(value: totalAmount)) ?? "£0")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(BrandTheme.ink)
                Text("\(filteredEntries.count) entries")
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.inkSoft)
            }
            Spacer()
            StatusPill(text: selectedSource?.label ?? "All", tone: BrandTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vintageCard()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [BrandTheme.surfaceStrong, BrandTheme.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var sourceFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton(label: "All", isSelected: selectedSource == nil) {
                    selectedSource = nil
                }
                ForEach(ManualSource.allCases) { source in
                    filterButton(label: source.label, isSelected: selectedSource == source) {
                        selectedSource = source
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: ManualEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(gbp.string(from: NSNumber(value: entry.amount)) ?? "£0")
                    .font(.headline)
                    .foregroundStyle(BrandTheme.ink)
                Spacer()
                StatusPill(text: entry.source.label.uppercased(), tone: BrandTheme.accent)
            }
            Text(friendlyDate(entry.date))
                .font(.caption)
                .foregroundStyle(BrandTheme.inkSoft)

            if let description = entry.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.inkSoft)
            }

            if let note = entry.note, !note.isEmpty {
                Text("Note: \(note)")
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.inkSoft)
            }

            HStack {
                Spacer()
                Button(role: .destructive) {
                    pendingDeleteEntry = entry
                } label: {
                    HStack(spacing: 4) {
                        if vm.deletingIds.contains(entry.id) {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "trash")
                                .font(.caption.weight(.bold))
                        }
                        Text(vm.deletingIds.contains(entry.id) ? "Deleting" : "Delete")
                            .font(.caption.weight(.semibold))
                    }
                }
                .disabled(vm.deletingIds.contains(entry.id))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(BrandTheme.surfaceStrong)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BrandTheme.outline, lineWidth: 1)
        )
    }

    private func filterButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? BrandTheme.accent.opacity(0.18) : BrandTheme.ink.opacity(0.08))
                )
                .foregroundStyle(isSelected ? BrandTheme.accent : BrandTheme.inkSoft)
        }
    }
}
