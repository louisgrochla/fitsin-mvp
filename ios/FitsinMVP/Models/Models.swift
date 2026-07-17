import Foundation

struct TodayMetrics: Codable {
    let actual_today: Double
    let target_today: Double
    let month_goal: Double?
    let remaining: Double
    let pct: Double
    let updated_at: String
    let data_delayed: Bool?
    let warning: String?
}

struct MonthDay: Codable, Identifiable {
    var id: String { date }
    let date: String
    let actual: Double
    let target: Double
}

struct MonthMetrics: Codable {
    let month_goal: Double?
    let mtd_actual: Double
    let mtd_target: Double
    let ahead_behind: Double
    let days: [MonthDay]
    let updated_at: String
    let data_delayed: Bool?
    let warning: String?
}

struct MonthGoalResponse: Codable {
    let month: String
    let goal: Double?
    let updated_at: String
}

struct CalendarEvent: Codable, Identifiable {
    let id: String
    let summary: String?
    let description: String?
    let location: String?
    let start: CalendarDateTime?
    let end: CalendarDateTime?
    let htmlLink: String?
    let created: String?
    let updated: String?

    var title: String { summary ?? "Untitled Event" }

    var startDate: Date? { start?.toDate() }
    var endDate: Date? { end?.toDate() }
    var isAllDay: Bool { start?.date != nil && start?.dateTime == nil }
}

struct CalendarDateTime: Codable {
    let dateTime: String?
    let date: String?
    let timeZone: String?

    private static let rfc3339: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let rfc3339NoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/London")
        return f
    }()

    func toDate() -> Date? {
        if let dt = dateTime {
            return Self.rfc3339.date(from: dt) ?? Self.rfc3339NoFrac.date(from: dt)
        }
        if let d = date {
            return Self.dateOnly.date(from: d)
        }
        return nil
    }
}

struct CalendarEventDraft {
    var title: String = ""
    var description: String = ""
    var location: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(3600)
    var isAllDay: Bool = false

    private static let rfc3339: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/London")
        return f
    }()

    func toRequestBody(timeZone: String) -> [String: Any] {
        var body: [String: Any] = [
            "summary": title
        ]

        if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["description"] = description
        }
        if !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["location"] = location
        }

        if isAllDay {
            body["start"] = ["date": Self.dateOnly.string(from: startDate)]
            body["end"] = ["date": Self.dateOnly.string(from: endDate)]
        } else {
            body["start"] = ["dateTime": Self.rfc3339.string(from: startDate), "timeZone": timeZone]
            body["end"] = ["dateTime": Self.rfc3339.string(from: endDate), "timeZone": timeZone]
        }

        return body
    }
}

struct GoogleCalendarEventsResponse: Decodable {
    let items: [CalendarEvent]?
    let nextPageToken: String?
}

enum ManualSource: String, Codable, CaseIterable, Identifiable {
    case vinted
    case website
    case cash
    case other

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct ManualEntry: Codable, Identifiable {
    let id: String
    let date: String
    let amount: Double
    let source: ManualSource
    let description: String?
    let note: String?
    let created_at: String
}

struct ManualEntriesResponse: Codable {
    let entries: [ManualEntry]
    let updated_at: String
}

struct DayLineItem: Codable, Identifiable {
    let name: String
    let quantity: Int
    let gross: Double
    let seller: String?
    let is_commission: Bool
    let commission: Double
    let store_net: Double

    // Stable-enough id for ForEach within a single order's breakdown.
    var id: String { "\(name)-\(quantity)-\(gross)" }
}

struct DaySaleItem: Codable, Identifiable {
    let id: String
    let kind: String
    let sold_at: String
    let description: String
    let quantity: Int
    let amount: Double?
    let store_net: Double?
    let has_commission: Bool?
    let line_items: [DayLineItem]?
    let source: String?
    let note: String?
    let order_name: String?
}

struct RotaEntry: Codable, Identifiable {
    let id: String
    let date: String
    let name: String
    let created_at: String
    let recurring: Bool?
}

struct RotaResponse: Codable {
    let entries: [RotaEntry]
    let updated_at: String
}

struct RotaSchedule: Codable {
    let id: String
    let name: String
    let days: [Int]  // 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat
    let created_at: String
}

struct RotaScheduleResponse: Codable {
    let schedule: RotaSchedule?
}

struct RotaSchedulesResponse: Codable {
    let schedules: [RotaSchedule]
    let updated_at: String
}

struct SellerSummary: Codable, Identifiable {
    let seller: String
    let total_gross: Double
    let total_commission: Double
    let total_net: Double
    let total_paid: Double?
    let total_unpaid: Double?
    let item_count: Int

    var id: String { seller }
}

struct SellerItem: Codable, Identifiable {
    let id: String
    let seller: String
    let item_name: String
    let quantity: Int
    let gross: Double
    let commission: Double
    let seller_net: Double
    let paid: Bool?
    let sold_at: String
    let date: String
    let order_name: String?
}

struct SellerSalesResponse: Codable {
    let sellers: [SellerSummary]
    let items: [SellerItem]
    let commission_rate: Double
    let month: String
    let updated_at: String
}

struct DaySalesResponse: Codable {
    let date: String
    let items: [DaySaleItem]
    let updated_at: String
    let data_delayed: Bool?
    let warning: String?
}
