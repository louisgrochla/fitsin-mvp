import UIKit
import XCTest

@MainActor
final class WorkspaceConnectedTests: XCTestCase {
  func testNativeStoreAgainstLoopbackWorkerD1AndR2() async throws {
    guard ProcessInfo.processInfo.environment["RUN_NATIVE_CONNECTED_TESTS"] == "YES" else {
      throw XCTSkip(
        "Opt in with RUN_NATIVE_CONNECTED_TESTS=YES and scripts/native-dev.mjs running on loopback")
    }
    // This test cannot address any production destination.
    let origin = URL(string: "http://127.0.0.1:31989")!
    let token = String(repeating: "z", count: 43)
    let api = WAPI(origin: origin, token: token)
    let response = try await WAPI(origin: origin).request(
      "/native/session", method: "POST",
      json: .object([
        "invite": .string(String(repeating: "n", count: 43)), "token": .string(token),
        "sessionId": .string("hostless-native-check"), "deviceId": .string("hostless-native-check"),
      ]))
    let actor = try JSONDecoder().decode(WActor.self, from: response)
    let identity = WSession(origin: origin, token: token, actor: actor)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = WorkspaceModel(
      restoringSession: false, baseDirectory: root, automaticallySync: false)
    try model.open(identity)
    model.reserveSKUs()
    await model.refresh()
    XCTAssertEqual(model.pendingCount, 0, model.notice ?? "")
    XCTAssertGreaterThan(model.availableSKUs, 0)
    let scan = WScan(description: "Native connected jacket", size: "M", price: 2550)
    try model.accept(scan)
    let item = try model.createDraft(scan: scan)
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 120))
    let image = renderer.image { context in
      UIColor.blue.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 80, height: 120))
    }
    let original = image.jpegData(compressionQuality: 1)!
    let prepared = try WPhotoPreparation.prepare(original)
    try model.addPhotos(item: item, originals: [prepared])
    // Reopen before syncing: accepted scan, SKU, dependent metadata and both
    // original/derivative upload bodies must survive the process boundary.
    let reopened = WorkspaceModel(
      restoringSession: false, baseDirectory: root, automaticallySync: false)
    try reopened.open(identity)
    XCTAssertEqual(reopened.item(item.id)?.sku, item.sku)
    XCTAssertGreaterThan(reopened.pendingCount, 3)
    await reopened.refresh()
    XCTAssertEqual(
      reopened.pendingCount, 0,
      reopened.needsAttention.map { $0.failure ?? "" }.joined(separator: "; "))
    let server = try await api.value("/native/v1/read/items/\(item.id)")
    XCTAssertEqual(server["status"].string, "draft")
    XCTAssertEqual(server["tagPrice"].int, 2550)
    XCTAssertEqual(server["photos"].array.count, 1)
    let photo = server["photos"].array[0]
    let photoID = photo["id"].string!
    let fetched = try await api.request(
      "/native/v1/read/items/\(item.id)/photos/\(photoID)/original")
    XCTAssertEqual(fetched, original)
    // A real web edit wins its revision. An older native edit is retained,
    // visibly blocked, and cannot overwrite that web change.
    var webRequest = URLRequest(url: origin.appendingPathComponent("api/items/\(item.id)"))
    webRequest.httpMethod = "PUT"
    webRequest.setValue("Bearer shared-synthetic-web", forHTTPHeaderField: "Authorization")
    webRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    var webInput = WItem(fields: server.object).input
    webInput["title"] = .string("Changed on web")
    webRequest.httpBody = try JSONEncoder().encode(WValue.object(webInput))
    let (_, webResponse) = try await URLSession.shared.data(for: webRequest)
    XCTAssertEqual((webResponse as? HTTPURLResponse)?.statusCode, 200)
    var stale = reopened.item(item.id)!
    stale.fields["title"] = .string("Older phone edit")
    try reopened.save(stale)
    await reopened.refresh()
    XCTAssertEqual(reopened.needsAttention.count, 1)
    let afterConflict = try await api.value("/native/v1/read/items/\(item.id)")
    XCTAssertEqual(afterConflict["title"].string, "Changed on web")
    XCTAssertEqual(reopened.item(item.id)?.text("title"), "Older phone edit")
    print(
      "CONNECTED NATIVE: real URLSession -> loopback Worker -> D1/R2; offline restart, scan/draft/photo and web conflict passed"
    )
  }
}
