import Foundation

// Where a tapped push notification should take the user. Kept deliberately small
// — the webhook only sends a sale date (for the day view) or a commission flag
// (for the seller view).
enum DeepLink: Identifiable, Equatable {
    case day(String)
    case seller

    var id: String {
        switch self {
        case .day(let date): return "day-\(date)"
        case .seller: return "seller"
        }
    }
}

@MainActor
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()

    // RootTabView observes this and presents the matching screen when it changes.
    @Published var pending: DeepLink?

    private init() {}

    func handle(_ userInfo: [AnyHashable: Any]) {
        let type = (userInfo["type"] as? String) ?? ""
        let date = (userInfo["date"] as? String) ?? ""

        switch type {
        case "commission_sale":
            pending = .seller
        case "new_sale":
            pending = date.isEmpty ? nil : .day(date)
        default:
            pending = date.isEmpty ? nil : .day(date)
        }
    }
}
