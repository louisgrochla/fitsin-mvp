import Foundation

enum WValue: Codable, Equatable, Hashable, Sendable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case object([String: WValue])
  case array([WValue])
  case null
  init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() {
      self = .null
    } else if let v = try? c.decode(String.self) {
      self = .string(v)
    } else if let v = try? c.decode(Double.self) {
      self = .number(v)
    } else if let v = try? c.decode(Bool.self) {
      self = .bool(v)
    } else if let v = try? c.decode([String: WValue].self) {
      self = .object(v)
    } else {
      self = .array(try c.decode([WValue].self))
    }
  }
  func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .string(let v): try c.encode(v)
    case .number(let v): try c.encode(v)
    case .bool(let v): try c.encode(v)
    case .object(let v): try c.encode(v)
    case .array(let v): try c.encode(v)
    case .null: try c.encodeNil()
    }
  }
  var string: String? {
    if case .string(let v) = self { return v }
    return nil
  }
  var int: Int? {
    if case .number(let v) = self, v.isFinite, v >= Double(Int.min), v < Double(Int.max) {
      return Int(v)
    }
    return nil
  }
  var object: [String: WValue] {
    if case .object(let v) = self { return v }
    return [:]
  }
  var array: [WValue] {
    if case .array(let v) = self { return v }
    return []
  }
  subscript(_ key: String) -> WValue { object[key] ?? .null }
  static func text(_ value: String) -> WValue { value.isEmpty ? .null : .string(value) }
}
struct WItem: Codable, Identifiable, Hashable, Sendable {
  var fields: [String: WValue]
  var id: String { text("id") }
  var sku: String { text("sku") }
  var title: String { text("tagItem").isEmpty ? text("title") : text("tagItem") }
  var status: String { text("status").isEmpty ? "draft" : text("status") }
  var revision: Int { fields["revision"]?.int ?? 0 }
  var photos: [WValue] { fields["photos"]?.array ?? [] }
  var listings: [WValue] { fields["listings"]?.array ?? [] }
  func text(_ key: String) -> String { fields[key]?.string ?? "" }
  func money(_ key: String) -> String {
    fields[key]?.int.map { String(format: "£%.2f", Double($0) / 100) } ?? "Not set"
  }
  var input: [String: WValue] {
    let names =
      "id sku title description sizeLabel keywords vinted brand size condition colour material garmentType era fit style ebayCategoryId ebayCategoryName tagItem tagSize tagCondition tagPrice measurements costPrice listPrice photos"
      .split(separator: " ").map(String.init)
    return fields.filter { names.contains($0.key) }
  }
}
struct WActor: Codable, Equatable, Sendable {
  var businessId: String, businessName: String, actorId: String, actorName: String,
    deviceId: String, sessionId: String, expiresAt: String
  var locationsEnabled: Bool?
}
struct WSession: Codable, Equatable, Sendable {
  var origin: URL, token: String, actor: WActor
  // Actor changes cannot inherit another person's unfinished queue.
  var scope: String {
    "\(origin.absoluteString)|\(actor.businessId)|\(actor.actorId)|\(actor.deviceId)"
  }
}
struct WEnrollment: Codable {
  var origin: URL, invite: String, token: String, sessionId: String, deviceId: String
}
struct WCommand: Codable, Identifiable, Equatable, Sendable {
  var id = UUID().uuidString
  var kind: String
  var itemId: String?
  var expectedRevision: Int?
  var data: [String: WValue] = [:]
  var dependsOn: String?
  var state = "pending"
  var failure: String?
  var attempted = false
  var attempts = 0
  var retryAt: Date?
  // Photo bodies live separately, never inflate the inventory snapshot.
  var photoPath: String?
  var photoId: String?
  var variant: String?
  var contentType: String?
  var createdAt = Date()
  var wire: [String: WValue] {
    var result: [String: WValue] = [
      "id": .string(id), "kind": .string(kind), "data": .object(data),
    ]
    if let itemId { result["itemId"] = .string(itemId) }
    if let expectedRevision { result["expectedRevision"] = .number(Double(expectedRevision)) }
    return result
  }
}
struct WSKUBlock: Codable, Sendable {
  var prefix: String
  var next: Int
  var end: Int
}
struct WScan: Codable, Identifiable, Equatable, Sendable {
  var id = UUID().uuidString
  var description: String, size: String, price: Int?
  var observedAt = Date()
  var itemId: String?
  var discarded = false
}
struct WPrintJob: Codable, Identifiable, Equatable, Sendable {
  var id = UUID().uuidString
  var item: WItem
  var format: String
  var state = "queued"
  var printerId: String?
  var failure: String?
  var attached = false
  var confirmationOperation: String?
  var createdAt = Date()
}
struct WSnapshot: Codable, Sendable {
  var schema = 1
  var scope: String
  var items: [WItem] = []
  var commands: [WCommand] = []
  var receipts: [String: Int] = [:]
  var blocks: [WSKUBlock] = []
  var scans: [WScan] = []
  var prints: [WPrintJob] = []
  var inventoryVersion: String?
  var lastRefresh: Date?
  var locations: WValue = .null
}
enum WError: LocalizedError {
  case message(String)
  case response(Int, String)
  var errorDescription: String? {
    switch self {
    case .message(let s), .response(_, let s): return s
    }
  }
}
enum WIdentity {
  // RFC 9562 UUIDv7: milliseconds then CSPRNG entropy. Stable after local save.
  static func itemID(now: Date = Date()) -> String {
    var bytes = withUnsafeBytes(of: UUID().uuid) { Array($0) }
    let ms = UInt64(now.timeIntervalSince1970 * 1000)
    for i in 0..<6 { bytes[i] = UInt8((ms >> ((5 - i) * 8)) & 255) }
    bytes[6] = (bytes[6] & 15) | 0x70
    bytes[8] = (bytes[8] & 63) | 0x80
    let hex = bytes.map { String(format: "%02x", $0) }.joined()
    let a = Array(hex)
    return [
      String(a[0..<8]), String(a[8..<12]), String(a[12..<16]), String(a[16..<20]),
      String(a[20..<32]),
    ].joined(separator: "-")
  }
}

enum WEntryParsing {
  static func money(_ text: String) throws -> Int? {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.isEmpty { return nil }
    guard value.range(of: #"^\d{1,5}(?:\.\d{0,2})?$"#, options: .regularExpression) != nil,
      let amount = Decimal(string: value), amount >= 0, amount <= 10000
    else {
      throw WError.message("Enter a price from £0 to £10,000 with no more than two decimal places")
    }
    return NSDecimalNumber(decimal: amount * 100).intValue
  }
}
