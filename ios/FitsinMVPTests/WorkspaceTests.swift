import UIKit
import Vision
import XCTest

final class WorkspaceCoreTests: XCTestCase {
  func testDecimalPriceEditingRejectsPartialAmbiguousOrFractionalPence() throws {
    XCTAssertEqual(try WEntryParsing.money("25.50"), 2550)
    XCTAssertEqual(try WEntryParsing.money("25."), 2500)
    XCTAssertNil(try WEntryParsing.money(""))
    for text in ["2O", "1.001", "-1", "10000.01", "20abc"] {
      XCTAssertThrowsError(try WEntryParsing.money(text))
    }
  }
  func testFiveThousandGarmentCacheReadSearchAndSave() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let disk = try WDisk(scope: "performance-synthetic", base: root)
    var snapshot = WSnapshot(scope: "performance-synthetic")
    snapshot.items = (1...5000).map { index in
      let photos: [WValue] = (0..<3).map { ordinal in
        .object([
          "id": .string("photo-\(index)-\(ordinal)"), "ordinal": .number(Double(ordinal)),
          "width": .number(1600), "height": .number(2000),
        ])
      }
      return WItem(fields: [
        "id": .string("synthetic-\(index)"), "sku": .string(String(format: "SY-%04d", index)),
        "title": .string("Wool jacket \(index)"),
        "description": .string(String(repeating: "Synthetic garment detail. ", count: 10)),
        "revision": .number(1), "tagPrice": .number(2500), "photos": .array(photos),
      ])
    }
    try disk.save(snapshot)
    let start = Date()
    var loaded = try disk.load(scope: snapshot.scope)
    let readMS = Date().timeIntervalSince(start) * 1000
    let searchStart = Date()
    let matches = loaded.items.filter { $0.sku.contains("0042") }
    let searchMS = Date().timeIntervalSince(searchStart) * 1000
    XCTAssertEqual(loaded.items.count, 5000)
    XCTAssertEqual(matches.count, 1)
    let openStart = Date()
    let item = loaded.items.first { $0.id == "synthetic-4999" }
    let openMS = Date().timeIntervalSince(openStart) * 1000
    XCTAssertEqual(item?.photos.count, 3)
    loaded.items[0].fields["title"] = .string("Saved edit")
    let saveStart = Date()
    try disk.save(loaded)
    let saveMS = Date().timeIntervalSince(saveStart) * 1000
    XCTAssertEqual(try disk.load(scope: snapshot.scope).items[0].title, "Saved edit")
    print(
      "SYNTHETIC 5000 CACHE: read_ms=\(readMS), search_ms=\(searchMS), item_lookup_ms=\(openMS), save_ms=\(saveMS), network_requests=0; simulator storage operations, not UI/device latency"
    )
  }
  func testUUIDv7AndExactMoneyJSON() throws {
    let id = WIdentity.itemID()
    XCTAssertNotNil(
      id.range(
        of: "^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
        options: .regularExpression))
    let value: WValue = .object(["tagPrice": .number(2550), "size": .string("M"), "unused": .null])
    XCTAssertEqual(try JSONDecoder().decode(WValue.self, from: JSONEncoder().encode(value)), value)
  }
  func testStableEvidenceAcceptsOnceAndRequiresTagExit() {
    var gate = StableTagGate()
    let reading = TagReading(description: "Blue jacket", size: "M", price: 2500)
    func evidence(
      _ time: Double, _ tag: CGRect = CGRect(x: 0.1, y: 0.1, width: 0.7, height: 0.7),
      ambiguous: Bool = false
    ) -> TagEvidence {
      TagEvidence(
        time: time, track: tag, reading: reading, confidence: 0.98, sharp: true,
        ambiguous: ambiguous)
    }
    for _ in 0..<10 { XCTAssertNil(gate.observe(evidence(1))) }
    for t in [1.4, 1.8, 2.2] { XCTAssertNil(gate.observe(evidence(t))) }
    XCTAssertEqual(gate.observe(evidence(2.6)), reading)
    for t in [3.0, 3.4, 3.8] { XCTAssertNil(gate.observe(evidence(t))) }
    XCTAssertNil(gate.observe(evidence(4.2, .zero)))
    XCTAssertNil(gate.observe(evidence(5.2, .zero)))
    for t in [5.6, 6.0, 6.4, 6.8] { XCTAssertNil(gate.observe(evidence(t))) }
    XCTAssertEqual(gate.observe(evidence(7.2)), reading)
  }
  func testRepeatedPixelFramesDoNotProvideIndependentEvidence() {
    var gate = StableTagGate()
    for i in 0..<20 {
      XCTAssertNil(
        gate.observe(
          TagEvidence(
            time: Double(i) * 0.4, track: CGRect(x: 0.1, y: 0.1, width: 0.7, height: 0.7),
            reading: TagReading(description: "Jacket", size: "M", price: 2500), confidence: 0.99,
            sharp: true, ambiguous: false, frameFingerprint: 42)))
    }
  }
  func testAmbiguityAndGapsCannotAutoAccept() {
    var gate = StableTagGate()
    let reading = TagReading(description: "Jacket", size: "M", price: 2000)
    for t in stride(from: 1.0, through: 10.0, by: 1.0) {
      XCTAssertNil(
        gate.observe(
          TagEvidence(
            time: t, track: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5), reading: reading,
            confidence: 0.99, sharp: true, ambiguous: false)))
    }
    for i in 0..<10 {
      XCTAssertNil(
        gate.observe(
          TagEvidence(
            time: 11 + Double(i) * 0.4, track: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5),
            reading: reading, confidence: 0.99, sharp: true, ambiguous: true)))
    }
    XCTAssertNil(TagParser.parse(["Jacket", "M", "£25", "£20"]).0)
    XCTAssertNil(TagParser.parse(["Jacket", "M", "£2O"]).0)
    XCTAssertEqual(TagParser.parse(["Blue wool jacket", "Size: M", "£25.50"]).0?.price, 2550)
  }
  func testDiskIsolationCorruptionAndSendingPrintRecoveryData() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let a = try WDisk(scope: "business-a|staff-a", base: root)
    let b = try WDisk(scope: "business-b|staff-a", base: root)
    var snapshot = WSnapshot(scope: "business-a|staff-a")
    snapshot.commands = [WCommand(kind: "sku.reserve")]
    try a.save(snapshot)
    XCTAssertEqual(try a.load(scope: snapshot.scope).commands.count, 1)
    XCTAssertTrue(try b.load(scope: "business-b|staff-a").commands.isEmpty)
    XCTAssertThrowsError(try a.load(scope: "wrong-identity"))
    try Data("corrupt".utf8).write(to: a.root.appendingPathComponent("workspace.json"))
    XCTAssertThrowsError(try a.load(scope: snapshot.scope))
    XCTAssertEqual(
      try Data(contentsOf: a.root.appendingPathComponent("workspace.json")), Data("corrupt".utf8))
  }
  func testM02RasterBlocksAndBitsAreBounded() throws {
    var pixels = [UInt8](repeating: 255, count: 384 * 256)
    pixels[0] = 0
    pixels[384 * 255 + 7] = 0
    let chunks = try M02Protocol.raster(pixels, height: 256)
    let wire = chunks.reduce(Data(), +)
    XCTAssertTrue(chunks.allSatisfy { $0.count <= 128 })
    XCTAssertEqual(wire.prefix(9), M02Protocol.initialize)
    XCTAssertEqual(Array(wire[9..<17]), [0x1d, 0x76, 0x30, 0, 48, 0, 255, 0])
    XCTAssertEqual(wire[17], 0x80)
    let second = 17 + 255 * 48
    XCTAssertEqual(Array(wire[second..<second + 8]), [0x1d, 0x76, 0x30, 0, 48, 0, 1, 0])
    XCTAssertEqual(wire[second + 8], 1)
    XCTAssertEqual(wire.suffix(M02Protocol.park.count), M02Protocol.park)
  }
  func testRenderedBarcodeDecodesToStableSKU() throws {
    let item = WItem(fields: [
      "id": .string(WIdentity.itemID()), "sku": .string("SY-0042"),
      "tagItem": .string("Blue wool jacket"), "tagPrice": .number(2550), "tagSize": .string("M"),
    ])
    for format in ["strip", "full"] {
      let (image, chunks) = try M02Protocol.render(item: item, format: format)
      let attachment = XCTAttachment(image: image)
      attachment.name = "native-sticker-\(format)"
      attachment.lifetime = .keepAlways
      add(attachment)
      XCTAssertEqual(image.cgImage?.width, 384)
      XCTAssertFalse(chunks.isEmpty)
      let request = VNDetectBarcodesRequest()
      request.symbologies = [.code128]
      request.revision = VNDetectBarcodesRequestRevision1
      request.usesCPUOnly = true
      try VNImageRequestHandler(cgImage: image.cgImage!, options: [:]).perform([request])
      XCTAssertEqual(request.results?.first?.payloadStringValue, item.sku)
    }
  }
}

private final class WorkspaceURLProtocol: URLProtocol {
  static var handler: ((URLRequest) throws -> (Int, Data))?
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    do {
      guard let handler = Self.handler else { throw URLError(.notConnectedToInternet) }
      let (status, data) = try handler(request)
      client?.urlProtocol(
        self,
        didReceive: HTTPURLResponse(
          url: request.url!, statusCode: status, httpVersion: nil,
          headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch { client?.urlProtocol(self, didFailWithError: error) }
  }
  override func stopLoading() {}
}
@MainActor
final class WorkspaceOutboxTests: XCTestCase {
  private var root: URL!
  private var transport: URLSession!
  private var identity: WSession!
  override func setUp() async throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [WorkspaceURLProtocol.self]
    transport = URLSession(configuration: config)
    identity = WSession(
      origin: URL(string: "https://synthetic.invalid")!, token: String(repeating: "t", count: 43),
      actor: WActor(
        businessId: "business", businessName: "Synthetic", actorId: "staff", actorName: "Tester",
        deviceId: "phone", sessionId: "session", expiresAt: "2099-01-01T00:00:00Z"))
  }
  override func tearDown() async throws {
    WorkspaceURLProtocol.handler = nil
    transport.invalidateAndCancel()
    try? FileManager.default.removeItem(at: root)
  }
  private func model() throws -> WorkspaceModel {
    let model = WorkspaceModel(
      restoringSession: false, baseDirectory: root, transport: transport, automaticallySync: false)
    try model.open(identity)
    return model
  }
  func testRestartKeepsOperationAndSKUAndMarksInterruptedPrintUncertain() throws {
    let first = try model()
    try first.update { $0.blocks = [WSKUBlock(prefix: "SY", next: 1, end: 50)] }
    let item = try first.createDraft(scan: WScan(description: "Jacket", size: "M", price: 2000))
    try first.enqueuePrint(item: item, format: "strip")
    let print = first.snapshot.prints[0]
    try first.setPrint(print.id, state: "sending")
    let second = try model()
    XCTAssertEqual(second.snapshot.commands.first?.id, first.snapshot.commands.first?.id)
    XCTAssertEqual(second.snapshot.items.first?.sku, "SY-0001")
    XCTAssertEqual(second.availableSKUs, 49)
    XCTAssertEqual(second.snapshot.prints[0].state, "uncertain")
    var other = identity!
    other.actor.actorId = "other-staff"
    try second.open(other)
    XCTAssertTrue(second.snapshot.items.isEmpty)
    XCTAssertTrue(second.snapshot.commands.isEmpty)
    try second.open(identity)
    XCTAssertEqual(second.snapshot.commands.count, 1)
  }
  func testRepeatedDraftActionKeepsOneGarmentAndOneSKU() throws {
    let model = try model()
    try model.update { $0.blocks = [WSKUBlock(prefix: "SY", next: 1, end: 50)] }
    let scan = WScan(description: "Jacket", size: "M", price: 2000)
    try model.accept(scan)
    let first = try model.createDraft(scan: scan)
    let second = try model.createDraft(scan: scan)
    XCTAssertEqual(first.id, second.id)
    XCTAssertEqual(model.availableSKUs, 49)
    XCTAssertEqual(model.snapshot.items.count, 1)
  }
  func testDiskFailureDoesNotConsumeSKUOrAcknowledgeScan() throws {
    let model = try model()
    try model.update { $0.blocks = [WSKUBlock(prefix: "SY", next: 1, end: 50)] }
    let disk = try WDisk(scope: identity.scope, base: root)
    let path = disk.root.appendingPathComponent("workspace.json")
    try FileManager.default.removeItem(at: path)
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
    XCTAssertThrowsError(try model.createDraft())
    XCTAssertEqual(model.availableSKUs, 50)
    XCTAssertTrue(model.snapshot.items.isEmpty)
    XCTAssertThrowsError(try model.accept(WScan(description: "Jacket", size: "M", price: 2000)))
    XCTAssertTrue(model.snapshot.scans.isEmpty)
  }
  func testLostReplyReplaysSameBodyAndDependentCommandUsesReceiptRevision() async throws {
    let model = try model()
    try model.update { $0.blocks = [WSKUBlock(prefix: "SY", next: 1, end: 50)] }
    var item = try model.createDraft()
    item.fields["title"] = .string("Second edit")
    try model.save(item)
    let actorData = try JSONEncoder().encode(identity.actor)
    var firstPayload: WValue?
    var calls = 0
    var versions: [Int] = []
    WorkspaceURLProtocol.handler = { request in
      if request.url!.path.hasSuffix("session") { return (200, actorData) }
      if request.url!.path.hasSuffix("commands") {
        let payload = try JSONDecoder().decode(WValue.self, from: Self.body(request))
        calls += 1
        if calls == 1 {
          firstPayload = payload
          throw URLError(.networkConnectionLost)
        }
        if calls == 2 { XCTAssertEqual(payload, firstPayload) }
        versions.append(payload["expectedRevision"].int ?? -1)
        return (
          200,
          try JSONEncoder().encode(
            WValue.object(["revision": .number(calls == 2 ? 7 : 9), "applied": .bool(true)]))
        )
      }
      return (200, Data("{\"items\":[]}".utf8))
    }
    await model.refresh()
    XCTAssertEqual(model.pendingCount, 2)
    let restarted = try self.model()
    try restarted.update { for i in $0.commands.indices { $0.commands[i].retryAt = nil } }
    await restarted.refresh()
    XCTAssertEqual(restarted.pendingCount, 0)
    XCTAssertEqual(versions, [0, 7])
    XCTAssertEqual(calls, 3)
  }
  func testConflictRetainsDraftAndRevocationStopsQueue() async throws {
    let model = try model()
    try model.update { $0.blocks = [WSKUBlock(prefix: "SY", next: 1, end: 50)] }
    let item = try model.createDraft()
    let actorData = try JSONEncoder().encode(identity.actor)
    WorkspaceURLProtocol.handler = { request in
      if request.url!.path.hasSuffix("session") { return (200, actorData) }
      if request.url!.path.hasSuffix("commands") {
        return (409, Data("{\"error\":\"Changed by web\"}".utf8))
      }
      return (200, Data("{\"items\":[]}".utf8))
    }
    await model.refresh()
    XCTAssertEqual(model.needsAttention.count, 1)
    XCTAssertEqual(model.snapshot.items.first?.id, item.id)
    WorkspaceURLProtocol.handler = { _ in (401, Data("{\"error\":\"Revoked\"}".utf8)) }
    await model.refresh()
    XCTAssertTrue(model.locked)
    XCTAssertEqual(model.pendingCount, 1)
  }
  func testEditorOpenedBeforeCreateSyncUsesCreationReceiptAfterItCompletes() async throws {
    let model = try model()
    try model.update { $0.blocks = [WSKUBlock(prefix: "SY", next: 1, end: 50)] }
    var editor = try model.createDraft()
    let actorData = try JSONEncoder().encode(identity.actor)
    var expected: [Int] = []
    var remote = editor
    remote.fields["revision"] = .number(7)
    let inventory = try JSONEncoder().encode(
      WValue.object(["items": .array([.object(remote.fields)])]))
    WorkspaceURLProtocol.handler = { request in
      if request.url!.path.hasSuffix("session") { return (200, actorData) }
      if request.url!.path.hasSuffix("commands") {
        let value = try JSONDecoder().decode(WValue.self, from: Self.body(request))
        expected.append(value["expectedRevision"].int ?? -1)
        return (200, Data("{\"revision\":7}".utf8))
      }
      return (200, inventory)
    }
    await model.refresh()
    XCTAssertEqual(model.pendingCount, 0)
    editor.fields["brand"] = .string("First editor save")
    try model.save(editor)
    await model.refresh()
    XCTAssertEqual(expected, [0, 7])
    XCTAssertEqual(model.pendingCount, 0)
  }
  func testUnchangedInventoryDoesNotDownloadCatalogueAgain() async throws {
    let model = try model()
    let actorData = try JSONEncoder().encode(identity.actor)
    var version = "first"
    var reads = 0
    var checks = 0
    WorkspaceURLProtocol.handler = { request in
      let path = request.url!.path
      if path.hasSuffix("session") { return (200, actorData) }
      if path.hasSuffix("inventory-version") {
        checks += 1
        return (200, Data("{\"version\":\"\(version)\"}".utf8))
      }
      if path.hasSuffix("items") {
        reads += 1
        return (200, Data("{\"items\":[]}".utf8))
      }
      return (200, Data("{}".utf8))
    }
    await model.refresh()
    await model.refresh()
    XCTAssertEqual(reads, 1)
    XCTAssertEqual(checks, 2)
    version = "changed-by-web"
    await model.refresh()
    XCTAssertEqual(reads, 2)
  }
  private nonisolated static func body(_ request: URLRequest) throws -> Data {
    if let data = request.httpBody { return data }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var result = Data()
    var bytes = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
      let n = stream.read(&bytes, maxLength: bytes.count)
      if n <= 0 { break }
      result.append(contentsOf: bytes[0..<n])
    }
    return result
  }
}
