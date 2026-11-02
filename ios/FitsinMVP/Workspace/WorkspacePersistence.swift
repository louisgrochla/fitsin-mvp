import CryptoKit
import Foundation
import Security

struct WDisk {
  let root: URL
  init(scope: String, base: URL? = nil) throws {
    let parent =
      try base
      ?? FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
      ).appendingPathComponent("NativeWorkspace", isDirectory: true)
    let key = SHA256.hash(data: Data(scope.utf8)).map { String(format: "%02x", $0) }.joined()
    root = parent.appendingPathComponent(key, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    var url = root
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try url.setResourceValues(values)
  }
  func load(scope: String) throws -> WSnapshot {
    let url = root.appendingPathComponent("workspace.json")
    guard FileManager.default.fileExists(atPath: url.path) else { return WSnapshot(scope: scope) }
    let snapshot = try JSONDecoder().decode(WSnapshot.self, from: Data(contentsOf: url))
    guard snapshot.schema == 1, snapshot.scope == scope else {
      throw WError.message("This saved workspace belongs to a different identity or app version.")
    }
    return snapshot
  }
  func save(_ snapshot: WSnapshot) throws {
    let data = try JSONEncoder().encode(snapshot)
    try data.write(
      to: root.appendingPathComponent("workspace.json"),
      options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }
  func writePhoto(_ bytes: Data, name: String) throws -> String {
    guard name.range(of: "^[a-zA-Z0-9_-]+\\.(jpg|png|heic)$", options: .regularExpression) != nil
    else { throw WError.message("Invalid photo name") }
    try bytes.write(
      to: root.appendingPathComponent(name),
      options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    return name
  }
  func photo(_ name: String) throws -> Data {
    guard !name.contains("/"), !name.contains("..") else {
      throw WError.message("Invalid photo path")
    }
    return try Data(contentsOf: root.appendingPathComponent(name))
  }
}
enum WKeychain {
  private static let service = "com.fitsin.native-workspace.v1"
  static func save<T: Encodable>(_ value: T, account: String) throws {
    let data = try JSONEncoder().encode(value)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    let status = SecItemUpdate(
      query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if status == errSecItemNotFound {
      var add = query
      add[kSecValueData as String] = data
      add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else {
        throw WError.message("Could not safely save the device session")
      }
    } else if status != errSecSuccess {
      throw WError.message("Keychain is locked or unavailable")
    }
  }
  static func read<T: Decodable>(_ type: T.Type, account: String) throws -> T? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrAccount as String: account, kSecReturnData as String: true,
    ]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data else {
      throw WError.message("Unlock your phone to open the workspace")
    }
    return try JSONDecoder().decode(type, from: data)
  }
  static func remove(_ account: String) {
    SecItemDelete(
      [
        kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
        kSecAttrAccount as String: account,
      ] as CFDictionary)
  }
  static func secret() throws -> String {
    var data = Data(count: 32)
    let status = data.withUnsafeMutableBytes {
      SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
    }
    guard status == errSecSuccess else { throw WError.message("Could not create a secure session") }
    return data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(
      of: "/", with: "_"
    ).replacingOccurrences(of: "=", with: "")
  }
}
final class WRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  static let session = URLSession(
    configuration: .ephemeral, delegate: WRedirectPolicy(), delegateQueue: nil)
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    // Never forward a workspace credential or upload body to a redirect target.
    completionHandler(nil)
  }
}
struct WAPI: Sendable {
  let origin: URL
  var token: String?
  var session: URLSession = WRedirectPolicy.session
  func request(
    _ path: String, method: String = "GET", json: WValue? = nil, bytes: Data? = nil,
    headers: [String: String] = [:]
  ) async throws -> Data {
    guard let url = URL(string: path, relativeTo: origin)?.absoluteURL, url.host == origin.host,
      url.port == origin.port, url.scheme == origin.scheme
    else { throw WError.message("Invalid workspace route") }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.timeoutInterval = 25
    request.cachePolicy = .reloadIgnoringLocalCacheData
    if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
    if let json {
      request.httpBody = try JSONEncoder().encode(json)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    if let bytes { request.httpBody = bytes }
    for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw WError.message("No server response")
    }
    guard (200..<300).contains(http.statusCode) else {
      let message =
        (try? JSONDecoder().decode(WValue.self, from: data))?["error"].string
        ?? "Server returned \(http.statusCode)"
      throw WError.response(http.statusCode, message)
    }
    return data
  }
  func value(_ path: String, method: String = "GET", json: WValue? = nil) async throws -> WValue {
    try JSONDecoder().decode(WValue.self, from: await request(path, method: method, json: json))
  }
}
