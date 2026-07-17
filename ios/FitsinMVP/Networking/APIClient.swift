import Foundation

enum APIError: Error {
    case invalidURL
    case unauthorized
    case noCode
    case missingBaseURL
    case decoding
    case server(String)
}

final class APIClient {
    static let shared = APIClient()

    private var baseURL: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: raw),
              !raw.isEmpty else {
            fatalError("Missing API_BASE_URL in Info.plist")
        }
        return url
    }

    private static let appCode = "8927374"

    private func request(path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(Self.appCode, forHTTPHeaderField: "X-APP-CODE")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        req.timeoutInterval = 20
        return req
    }

    private func fetch<T: Decodable>(_ type: T.Type, path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        let req = try request(path: path, method: method, body: body)
        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.server("No HTTP response")
        }

        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.server("HTTP \(http.statusCode)")
        }

        if data.isEmpty {
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            throw APIError.decoding
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    func getToday() async throws -> TodayMetrics {
        try await fetch(TodayMetrics.self, path: "/v1/today")
    }

    func getMonth() async throws -> MonthMetrics {
        try await fetch(MonthMetrics.self, path: "/v1/month")
    }

    func getMonth(month: String) async throws -> MonthMetrics {
        let encoded = month.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? month
        return try await fetch(MonthMetrics.self, path: "/v1/month?month=\(encoded)")
    }

    func getMonthGoal(month: String) async throws -> MonthGoalResponse {
        try await fetch(MonthGoalResponse.self, path: "/v1/month-goal?month=\(month)")
    }

    func setMonthGoal(month: String, goal: Double?) async throws -> MonthGoalResponse {
        let payload: [String: Any] = [
            "month": month,
            "goal": goal ?? NSNull()
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        return try await fetch(MonthGoalResponse.self, path: "/v1/month-goal", method: "PUT", body: body)
    }

    func createManualEntry(
        amount: Double,
        source: ManualSource,
        description: String?,
        note: String?,
        date: String? = nil
    ) async throws -> ManualEntry {
        var payload: [String: Any] = [
            "amount": amount,
            "source": source.rawValue,
            "description": (description?.isEmpty == false ? description as Any : NSNull()),
            "note": (note?.isEmpty == false ? note as Any : NSNull())
        ]
        if let date, !date.isEmpty { payload["date"] = date }
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        return try await fetch(ManualEntry.self, path: "/v1/manual-entries", method: "POST", body: body)
    }

    func getManualEntries(from: String? = nil, to: String? = nil, limit: Int = 200) async throws -> ManualEntriesResponse {
        var parts = [String]()
        if let from, !from.isEmpty { parts.append("from=\(from)") }
        if let to, !to.isEmpty { parts.append("to=\(to)") }
        parts.append("limit=\(limit)")
        let query = parts.joined(separator: "&")
        return try await fetch(ManualEntriesResponse.self, path: "/v1/manual-entries?\(query)")
    }

    func deleteManualEntry(id: String) async throws {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        _ = try await fetch(EmptyResponse.self, path: "/v1/manual-entries/\(encoded)", method: "DELETE")
    }

    func warmUp() async {
        guard let url = URL(string: "/v1/today", relativeTo: baseURL) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.timeoutInterval = 10
        if let code = KeychainStore.readCode(), !code.isEmpty {
            req.setValue(code, forHTTPHeaderField: "X-APP-CODE")
        }
        _ = try? await URLSession.shared.data(for: req)
    }

    func getDaySales(date: String) async throws -> DaySalesResponse {
        let encoded = date.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? date
        return try await fetch(DaySalesResponse.self, path: "/v1/day?date=\(encoded)")
    }

    // MARK: - Devices (Push)

    func registerDevice(token: String, name: String, preferences: [String: Any]) async throws {
        let payload: [String: Any] = ["token": token, "name": name, "preferences": preferences]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        _ = try await fetch(EmptyResponse.self, path: "/v1/devices", method: "POST", body: body)
    }

    func getDevice(token: String) async throws -> DeviceResponse {
        let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
        return try await fetch(DeviceResponse.self, path: "/v1/devices/\(encoded)")
    }

    func updateDevicePreferences(token: String, preferences: [String: Any]) async throws {
        let payload: [String: Any] = ["token": token, "preferences": preferences]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        _ = try await fetch(EmptyResponse.self, path: "/v1/devices", method: "PUT", body: body)
    }

    func removeDevice(token: String) async throws {
        let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
        _ = try await fetch(EmptyResponse.self, path: "/v1/devices/\(encoded)", method: "DELETE")
    }

    // MARK: - Sellers

    func getSellerSales(month: String) async throws -> SellerSalesResponse {
        let encoded = month.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? month
        return try await fetch(SellerSalesResponse.self, path: "/v1/sellers?month=\(encoded)")
    }

    // Mark a consignment seller line item as paid / unpaid. Shared across every
    // device via the backend, so payout status stays consistent for the team.
    func setSellerItemPaid(itemId: String, paid: Bool, by: String? = nil) async throws {
        var payload: [String: Any] = ["item_id": itemId, "paid": paid]
        if let by, !by.isEmpty { payload["by"] = by }
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        _ = try await fetch(EmptyResponse.self, path: "/v1/sellers/paid", method: "PUT", body: body)
    }

    // MARK: - Rota

    func getRotaEntries(from: String, to: String) async throws -> RotaResponse {
        try await fetch(RotaResponse.self, path: "/v1/rota?from=\(from)&to=\(to)")
    }

    func addRotaEntry(date: String, name: String) async throws -> RotaEntry {
        let payload: [String: Any] = ["date": date, "name": name]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        return try await fetch(RotaEntry.self, path: "/v1/rota", method: "POST", body: body)
    }

    func deleteRotaEntry(id: String) async throws {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        _ = try await fetch(EmptyResponse.self, path: "/v1/rota/\(encoded)", method: "DELETE")
    }

    func getMySchedule(name: String) async throws -> RotaScheduleResponse {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return try await fetch(RotaScheduleResponse.self, path: "/v1/rota/schedule?name=\(encoded)")
    }

    func setSchedule(name: String, days: [Int]) async throws -> RotaSchedulesResponse {
        let payload: [String: Any] = ["name": name, "days": days]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        return try await fetch(RotaSchedulesResponse.self, path: "/v1/rota/schedule", method: "PUT", body: body)
    }
}

private struct EmptyResponse: Decodable {}

struct DeviceResponse: Decodable {
    let name: String?
    let preferences: DevicePreferences

    struct DevicePreferences: Decodable {
        let newSale: Bool
        let myCommissionSale: Bool
        let dailySummary: Bool
        let rotaReminder: Bool
        let sellerPrefix: String?

        enum CodingKeys: String, CodingKey {
            case newSale = "new_sale"
            case myCommissionSale = "my_commission_sale"
            case dailySummary = "daily_summary"
            case rotaReminder = "rota_reminder"
            case sellerPrefix = "seller_prefix"
        }
    }
}
