import Foundation
import Network
import SwiftUI

@MainActor
final class WorkspaceModel: ObservableObject {
  @Published private(set) var session: WSession?
  @Published private(set) var snapshot = WSnapshot(scope: "signed-out")
  @Published var notice: String?
  @Published private(set) var syncing = false
  @Published private(set) var online = true
  @Published private(set) var locked = false
  @Published private(set) var opening = false
  private var disk: WDisk?
  private var epoch = UUID()
  private var runner: Task<Void, Never>?
  private let monitor = NWPathMonitor()
  private let baseDirectory: URL?
  private let transport: URLSession
  private let automaticallySync: Bool
  var api: WAPI? { session.map { WAPI(origin: $0.origin, token: $0.token, session: transport) } }
  var pendingCount: Int { snapshot.commands.count }
  var needsAttention: [WCommand] { snapshot.commands.filter { $0.state == "blocked" } }
  var availableSKUs: Int { snapshot.blocks.reduce(0) { $0 + max(0, $1.end - $1.next + 1) } }

  init(
    restoringSession: Bool = true, baseDirectory: URL? = nil,
    transport: URLSession = WRedirectPolicy.session, automaticallySync: Bool = true
  ) {
    self.baseDirectory = baseDirectory
    self.transport = transport
    self.automaticallySync = automaticallySync
    do {
      if restoringSession, let saved = try WKeychain.read(WSession.self, account: "session") {
        opening = true
        Task {
          do { try await restore(saved) } catch {
            self.notice = error.localizedDescription
            self.locked = true
            self.opening = false
          }
        }
      }
    } catch {
      notice = error.localizedDescription
      locked = true
    }
    monitor.pathUpdateHandler = { [weak self] path in
      Task { @MainActor in
        self?.online = path.status == .satisfied
        if path.status == .satisfied { self?.startSync() }
      }
    }
    if automaticallySync {
      monitor.start(queue: DispatchQueue(label: "fitsin.workspace.connectivity"))
    }
  }
  private func restore(_ session: WSession) async throws {
    let ticket = UUID()
    epoch = ticket
    opening = true
    let base = baseDirectory
    let (newDisk, loaded) = try await Task.detached(priority: .userInitiated) {
      let disk = try WDisk(scope: session.scope, base: base)
      var value = try disk.load(scope: session.scope)
      for i in value.prints.indices where value.prints[i].state == "sending" {
        value.prints[i].state = "uncertain"
        value.prints[i].failure =
          "Printing was interrupted. Inspect the sticker before confirming or reprinting."
      }
      try disk.save(value)
      return (disk, value)
    }.value
    guard epoch == ticket else { throw CancellationError() }
    install(session, disk: newDisk, snapshot: loaded)
    opening = false
  }
  func open(_ session: WSession) throws {
    let newDisk = try WDisk(scope: session.scope, base: baseDirectory)
    var loaded = try newDisk.load(scope: session.scope)
    // A disconnect/restart cannot tell us whether paper emerged.
    for i in loaded.prints.indices where loaded.prints[i].state == "sending" {
      loaded.prints[i].state = "uncertain"
      loaded.prints[i].failure =
        "Printing was interrupted. Inspect the sticker before confirming or reprinting."
    }
    try newDisk.save(loaded)
    install(session, disk: newDisk, snapshot: loaded)
  }
  private func install(_ session: WSession, disk newDisk: WDisk, snapshot loaded: WSnapshot) {
    epoch = UUID()
    runner?.cancel()
    runner = nil
    syncing = false
    disk = newDisk
    snapshot = loaded
    self.session = session
    locked = false
    opening = false
    startSync()
  }
  func enroll(originText: String, invitation: String) async {
    do {
      guard let origin = URL(string: originText.trimmingCharacters(in: .whitespacesAndNewlines)),
        origin.user == nil, origin.password == nil, origin.query == nil, origin.fragment == nil,
        origin.path.isEmpty || origin.path == "/",
        origin.scheme == "https"
          || (origin.scheme == "http"
            && ["127.0.0.1", "localhost", "::1"].contains(origin.host ?? ""))
      else {
        throw WError.message(
          "Use your workspace HTTPS address, or loopback for local verification.")
      }
      let saved = try WKeychain.read(WEnrollment.self, account: "enrollment")
      let device = try WKeychain.read(String.self, account: "device") ?? UUID().uuidString
      try WKeychain.save(device, account: "device")
      let invite = invitation.trimmingCharacters(in: .whitespacesAndNewlines)
      let pending: WEnrollment
      if let saved, saved.origin == origin, saved.invite == invite {
        pending = saved
      } else {
        pending = WEnrollment(
          origin: origin, invite: invite, token: try WKeychain.secret(),
          sessionId: UUID().uuidString, deviceId: device)
        try WKeychain.save(pending, account: "enrollment")
      }
      let body: WValue = .object([
        "invite": .string(pending.invite), "token": .string(pending.token),
        "sessionId": .string(pending.sessionId), "deviceId": .string(pending.deviceId),
      ])
      let data = try await WAPI(origin: origin).request(
        "/native/session", method: "POST", json: body)
      let actor = try JSONDecoder().decode(WActor.self, from: data)
      let session = WSession(origin: origin, token: pending.token, actor: actor)
      try WKeychain.save(session, account: "session")
      try await restore(session)
      WKeychain.remove("enrollment")
      notice = nil
      startSync()
    } catch {
      opening = false
      notice = error.localizedDescription
    }
  }
  func signOut(revoke: Bool) async {
    if revoke, let api {
      do { _ = try await api.request("/native/v1/session", method: "DELETE") } catch {
        notice = "Could not revoke this device: \(error.localizedDescription)"
        return
      }
    }
    epoch = UUID()
    runner?.cancel()
    runner = nil
    syncing = false
    session = nil
    disk = nil
    locked = false
    snapshot = WSnapshot(scope: "signed-out")
    WKeychain.remove("session")
    notice =
      "Signed out. Unsent work remains encrypted by device storage and isolated to its original workspace and staff identity."
  }
  // Mutations publish only after an atomic file replacement succeeds. A failed
  // write leaves the previous snapshot intact, so no acceptance/SKU is lost.
  func update(_ change: (inout WSnapshot) throws -> Void) throws {
    guard session != nil, !locked, let disk else {
      throw WError.message("Sign in to this workspace first")
    }
    var next = snapshot
    try change(&next)
    try disk.save(next)
    snapshot = next
  }
  private func append(_ command: WCommand, to state: inout WSnapshot) {
    var command = command
    if let itemId = command.itemId,
      let previous = state.commands.last(where: { $0.itemId == itemId })
    {
      command.dependsOn = previous.id
      command.expectedRevision = nil
    }
    if let take = command.data["stocktakeId"],
      let previous = state.commands.last(where: { $0.data["stocktakeId"] == take })
    {
      command.dependsOn = previous.id
    }
    state.commands.append(command)
  }
  @discardableResult func queue(_ kind: String, item: WItem? = nil, data: [String: WValue] = [:])
    throws -> String
  {
    var data = data
    if ["item.location", "item.location-undo", "stocktake.observe"].contains(kind) {
      data["observedAt"] =
        data["observedAt"] ?? .string(ISO8601DateFormatter().string(from: Date()))
      data["source"] = data["source"] ?? .string(kind == "item.location-undo" ? "undo" : "manual")
    }
    let command = WCommand(
      kind: kind, itemId: item?.id, expectedRevision: item?.revision, data: data)
    try update { append(command, to: &$0) }
    startSync()
    return command.id
  }
  func reserveSKUs() {
    do {
      if !snapshot.commands.contains(where: { $0.kind == "sku.reserve" }) {
        try queue("sku.reserve")
      }
    } catch { notice = error.localizedDescription }
  }
  @discardableResult func createDraft(scan: WScan? = nil) throws -> WItem {
    if let scan, let existing = snapshot.scans.first(where: { $0.id == scan.id })?.itemId {
      guard let item = item(existing) else {
        throw WError.message("This tag already belongs to a garment")
      }
      return item
    }
    var created: WItem!
    try update { state in
      guard let index = state.blocks.firstIndex(where: { $0.next <= $0.end }) else {
        throw WError.message(
          "Connect once to reserve SKU numbers. Accepted scans remain saved until then.")
      }
      let block = state.blocks[index]
      state.blocks[index].next += 1
      let sku = String(format: "%@-%04d", block.prefix, block.next)
      created = WItem(fields: [
        "id": .string(WIdentity.itemID()), "sku": .string(sku),
        "title": .string(scan?.description ?? ""), "tagItem": .text(scan?.description ?? ""),
        "tagSize": .text(scan?.size ?? ""),
        "tagPrice": scan?.price.map { .number(Double($0)) } ?? .null, "status": .string("draft"),
        "revision": .number(0),
      ])
      state.items.insert(created, at: 0)
      append(
        WCommand(kind: "item.save", itemId: created.id, expectedRevision: 0, data: created.input),
        to: &state)
      if let scan, let i = state.scans.firstIndex(where: { $0.id == scan.id }) {
        state.scans[i].itemId = created.id
        append(
          WCommand(kind: "item.scan-link", itemId: created.id, data: ["scanId": .string(scan.id)]),
          to: &state)
      }
      // An editor may stay open after creation/linking has already synced.
      // Keep its causal receipt, not a later background-refresh revision.
      created.fields["_creationOperation"] = state.commands.last(where: { $0.itemId == created.id })
        .map { .string($0.id) }
      state.items[0] = created
    }
    startSync()
    return created
  }
  func save(_ item: WItem) throws {
    try update { state in
      guard let i = state.items.firstIndex(where: { $0.id == item.id }) else {
        throw WError.message("Item no longer in this workspace")
      }
      // Editor keeps the revision at which it opened. It must not silently
      // adopt a newer background refresh and overwrite somebody's edit.
      var command = WCommand(
        kind: "item.save", itemId: item.id, expectedRevision: item.revision, data: item.input)
      if item.revision == 0, let creation = item.fields["_creationOperation"]?.string {
        command.dependsOn = creation
        command.expectedRevision = nil
      }
      append(command, to: &state)
      state.items[i] = item
    }
    startSync()
  }
  func accept(_ scan: WScan) throws {
    try update { state in
      guard !state.scans.contains(where: { $0.id == scan.id }) else { return }
      state.scans.insert(scan, at: 0)
      append(
        WCommand(
          id: scan.id, kind: "scan.accept",
          data: [
            "description": .string(scan.description), "size": .text(scan.size),
            "price": scan.price.map { .number(Double($0)) } ?? .null,
            "observedAt": .string(ISO8601DateFormatter().string(from: scan.observedAt)),
          ]), to: &state)
    }
    startSync()
  }
  func discardScan(_ scan: WScan) throws {
    try update { state in
      if let i = state.scans.firstIndex(where: { $0.id == scan.id }) {
        state.scans[i].discarded = true
      }
      var cmd = WCommand(kind: "scan.discard", data: ["scanId": .string(scan.id)])
      if state.commands.contains(where: { $0.id == scan.id }) { cmd.dependsOn = scan.id }
      state.commands.append(cmd)
    }
    startSync()
  }
  func startSync(force: Bool = false) {
    guard automaticallySync || force, runner == nil, session != nil, !locked else { return }
    let current = epoch
    runner = Task { [weak self] in
      guard let self else { return }
      self.syncing = true
      await self.synchronize(epoch: current)
      if self.epoch == current {
        self.syncing = false
        self.runner = nil
      }
    }
  }
  func refresh() async {
    startSync(force: true)
    await runner?.value
  }
  private func synchronize(epoch current: UUID) async {
    guard let api, let owner = session else { return }
    do {
      let sessionData = try await api.request("/native/v1/session")
      let actor = try JSONDecoder().decode(WActor.self, from: sessionData)
      guard current == epoch, actor.businessId == owner.actor.businessId,
        actor.actorId == owner.actor.actorId, actor.deviceId == owner.actor.deviceId
      else { return }
      session?.actor = actor
      let hadCommands = !snapshot.commands.isEmpty
      var attempted = Set<String>()
      while !Task.isCancelled, current == epoch {
        guard
          let chosen = snapshot.commands.first(where: { command in
            command.state != "blocked" && !attempted.contains(command.id)
              && (command.retryAt ?? .distantPast) <= Date()
              && (command.dependsOn == nil || snapshot.receipts[command.dependsOn!] != nil)
              && !snapshot.commands.contains(where: {
                $0.itemId != nil && $0.itemId == command.itemId && $0.createdAt < command.createdAt
                  && $0.state == "blocked"
              })
          })
        else { break }
        attempted.insert(chosen.id)
        try update { state in
          let i = state.commands.firstIndex(where: { $0.id == chosen.id })!
          if !state.commands[i].attempted, let dependency = state.commands[i].dependsOn,
            let revision = state.receipts[dependency], state.commands[i].itemId != nil
          {
            state.commands[i].expectedRevision = revision
          }
          state.commands[i].attempted = true
          state.commands[i].state = "sending"
          state.commands[i].attempts += 1
        }
        let command = snapshot.commands.first(where: { $0.id == chosen.id })!
        do {
          let result: WValue
          if let photo = command.photoPath, let itemId = command.itemId,
            let photoId = command.photoId, let variant = command.variant, let disk
          {
            let bytes = try disk.photo(photo)
            let data = try await api.request(
              "/native/v1/photos/\(itemId)/\(photoId)/\(variant)", method: "PUT", bytes: bytes,
              headers: [
                "Content-Type": command.contentType ?? "image/jpeg", "X-Operation-ID": command.id,
                "X-Expected-Revision": String(command.expectedRevision ?? -1),
              ])
            result = try JSONDecoder().decode(WValue.self, from: data)
          } else {
            result = try await api.value(
              "/native/v1/commands", method: "POST", json: .object(command.wire))
          }
          guard current == epoch else { return }
          var block: WSKUBlock?
          if command.kind == "sku.reserve" {
            let reserved = try await api.value("/native/v1/sku-blocks/\(command.id)")
            guard let from = reserved["from"].int, let to = reserved["to"].int,
              let prefix = reserved["prefix"].string
            else { throw WError.message("SKU reservation response is incomplete") }
            block = WSKUBlock(prefix: prefix, next: from, end: to)
          }
          guard current == epoch else { return }
          try update { state in
            state.receipts[command.id] = result["revision"].int ?? 0
            state.commands.removeAll { $0.id == command.id }
            if let block { state.blocks.append(block) }
            if let i = state.items.firstIndex(where: { $0.id == command.itemId }) {
              state.items[i].fields["revision"] = result["revision"]
            }
          }
        } catch {
          guard current == epoch else { return }
          if case WError.response(401, _) = error { throw error }
          let permanent: Bool
          if case WError.response(let code, _) = error {
            permanent = (400..<500).contains(code) && code != 429
          } else {
            permanent = false
          }
          try update { state in
            guard let i = state.commands.firstIndex(where: { $0.id == command.id }) else { return }
            state.commands[i].state = permanent ? "blocked" : "pending"
            state.commands[i].failure = error.localizedDescription
            state.commands[i].retryAt =
              permanent
              ? nil : Date().addingTimeInterval(min(60, pow(2, Double(min(command.attempts, 5)))))
          }
          if !permanent {
            notice = "Saved on this phone. Sync will resume when the connection recovers."
            break
          }
        }
      }
      let version = try await api.value("/native/v1/inventory-version")["version"].string
      guard current == epoch else { return }
      if version == nil || snapshot.inventoryVersion != version || hadCommands
        || !snapshot.commands.isEmpty
      {
        let data = try await api.value("/native/v1/read/items")
        guard current == epoch else { return }
        let rows = data.array.isEmpty ? data["items"].array : data.array
        // Validate shape before replacing a durable inventory with an empty response.
        guard case .array = (data.object["items"] ?? data) else {
          throw WError.message("Inventory response is incomplete")
        }
        let remote = rows.map { WItem(fields: $0.object) }
        try update { state in
          let pending = Set(state.commands.compactMap(\.itemId))
          let local = state.items.filter { pending.contains($0.id) }
          state.items = local + remote.filter { !pending.contains($0.id) }
          state.lastRefresh = Date()
          state.inventoryVersion = version
        }
      }
      let scanResponse = try await api.value("/native/v1/scans")
      guard current == epoch else { return }
      if case .array(let scans) = scanResponse["scans"] {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let shared = scans.compactMap { value -> WScan? in
          guard let id = value["id"].string, let description = value["description"].string else {
            return nil
          }
          let timestamp = value["observed_at"].string ?? ""
          let date =
            parser.date(from: timestamp) ?? ISO8601DateFormatter().date(from: timestamp)
            ?? .distantPast
          return WScan(
            id: id, description: description, size: value["size"].string ?? "",
            price: value["price"].int, observedAt: date, itemId: value["item_id"].string,
            discarded: value["state"].string == "discarded"
              || (value["state"].string == "draft" && value["item_id"] == .null))
        }
        try update { state in
          let pending = Set(
            state.commands.map(\.id) + state.commands.compactMap { $0.data["scanId"]?.string })
          state.scans =
            state.scans.filter { pending.contains($0.id) }
            + shared.filter { !pending.contains($0.id) }
        }
      }
      if actor.locationsEnabled == true {
        let locations = try await api.value("/native/v1/locations")
        guard current == epoch else { return }
        try update { $0.locations = locations }
      }
      if snapshot.commands.isEmpty { notice = nil }
    } catch {
      guard current == epoch else { return }
      if case WError.response(401, _) = error {
        locked = true
        notice =
          "This device session has expired or was revoked. Unsent work is retained for its original identity. Sign in again to continue."
      } else {
        notice = "Saved workspace available. \(error.localizedDescription)"
      }
    }
  }
  func retryPending() {
    do {
      try update { state in
        for i in state.commands.indices where state.commands[i].state != "blocked" {
          state.commands[i].retryAt = nil
        }
      }
      startSync()
    } catch { notice = error.localizedDescription }
  }
  func resolveUsingCurrent(
    _ command: WCommand, reviewedRevision: Int, editedData: [String: WValue]? = nil
  ) {
    // Explicit conflict review applies only to this saved command; dependent
    // drafts remain queued and keep their own data. Never mutate a sent ID.
    guard command.itemId != nil else { return }
    do {
      try update { state in
        guard let i = state.commands.firstIndex(where: { $0.id == command.id }) else { return }
        var replacement = command
        replacement.id = UUID().uuidString
        if let editedData { replacement.data = editedData }
        replacement.expectedRevision = reviewedRevision
        replacement.attempted = false
        replacement.attempts = 0
        replacement.state = "pending"
        replacement.failure = nil
        replacement.dependsOn = nil
        replacement.retryAt = nil
        state.commands[i] = replacement
        for j in state.commands.indices where state.commands[j].dependsOn == command.id {
          state.commands[j].dependsOn = replacement.id
        }
      }
      startSync()
    } catch { notice = error.localizedDescription }
  }
  func read(_ path: String) async throws -> WValue {
    guard !locked, let api else { throw WError.message("Sign in to continue") }
    let current = epoch
    let result = try await api.value("/native/v1/read/" + path)
    guard current == epoch else { throw CancellationError() }
    return result
  }
  func item(_ id: String) -> WItem? { snapshot.items.first { $0.id == id } }
  func photoData(_ item: WItem, photo: WValue) async throws -> Data {
    guard !locked, let disk, let id = photo["id"].string else {
      throw WError.message("Photo unavailable")
    }
    if let local = photo["localWeb"].string, let bytes = try? disk.photo(local) { return bytes }
    let cache = "cache-\(id).jpg"
    if let bytes = try? disk.photo(cache) { return bytes }
    guard let api else { throw WError.message("Connect to download this photograph") }
    let current = epoch
    let bytes = try await api.request("/native/v1/read/items/\(item.id)/photos/\(id)/web")
    guard epoch == current, !locked else { throw CancellationError() }
    _ = try disk.writePhoto(bytes, name: cache)
    return bytes
  }
  func addPhotos(item: WItem, originals: [WPreparedPhoto]) throws {
    guard let disk else { throw WError.message("Workspace unavailable") }
    guard item.photos.count + originals.count <= 30 else {
      throw WError.message("A garment can have up to 30 photographs")
    }
    var edited = self.item(item.id) ?? item
    var photos = edited.photos
    var uploads: [WCommand] = []
    for prepared in originals {
      let original = prepared.original
      let web = prepared.web
      let width = prepared.width
      let height = prepared.height
      let id = WIdentity.itemID()
      let originalName = try disk.writePhoto(
        original, name: "\(id)-original.\(prepared.extensionName)")
      let webName = try disk.writePhoto(web, name: "\(id)-web.jpg")
      photos.append(
        .object([
          "id": .string(id), "ordinal": .number(Double(photos.count)),
          "width": .number(Double(width)), "height": .number(Double(height)),
          "bytes": .number(Double(original.count)), "localWeb": .string(webName),
        ]))
      for (variant, path) in [("original", originalName), ("web", webName)] {
        uploads.append(
          WCommand(
            kind: "photo.upload", itemId: item.id, photoPath: path, photoId: id, variant: variant,
            contentType: variant == "original" ? prepared.contentType : "image/jpeg"))
      }
    }
    edited.fields["photos"] = .array(photos)
    try update { state in
      guard let i = state.items.firstIndex(where: { $0.id == item.id }) else {
        throw WError.message("Item not available")
      }
      state.items[i] = edited
      append(
        WCommand(
          kind: "item.save", itemId: item.id, expectedRevision: edited.revision, data: edited.input),
        to: &state)
      for command in uploads { append(command, to: &state) }
    }
    startSync()
  }
  func enqueuePrint(item: WItem, format: String) throws {
    guard !item.sku.isEmpty, item.fields["tagPrice"]?.int != nil else {
      throw WError.message("Reserve a SKU and set the shop price before printing")
    }
    try update { $0.prints.append(WPrintJob(item: item, format: format)) }
  }
  func setPrint(_ id: String, state: String, printer: String? = nil, error: String? = nil) throws {
    try update { value in
      guard let i = value.prints.firstIndex(where: { $0.id == id }) else { return }
      value.prints[i].state = state
      value.prints[i].failure = error
      if let printer { value.prints[i].printerId = printer }
    }
  }
  func confirmPrint(_ id: String) throws {
    try update { state in
      guard let i = state.prints.firstIndex(where: { $0.id == id }),
        state.prints[i].confirmationOperation == nil
      else { return }
      let item = state.items.first { $0.id == state.prints[i].item.id } ?? state.prints[i].item
      let printed = state.prints[i].item
      let keys = ["sku", "tagItem", "tagSize", "tagPrice", "tagCondition"]
      guard keys.allSatisfy({ (item.fields[$0] ?? .null) == (printed.fields[$0] ?? .null) }) else {
        throw WError.message(
          "The garment's tag details changed. Queue and check a new sticker before confirming.")
      }
      let command = WCommand(
        kind: "item.print-confirm", itemId: item.id, expectedRevision: item.revision,
        data: [
          "printedTag": .object(
            Dictionary(uniqueKeysWithValues: keys.map { ($0, printed.fields[$0] ?? .null) }))
        ])
      append(command, to: &state)
      state.prints[i].confirmationOperation = command.id
      state.prints[i].state = "confirmed"
    }
    startSync()
  }
  func attachPrint(_ id: String) throws {
    try update { state in
      if let i = state.prints.firstIndex(where: { $0.id == id }) { state.prints[i].attached = true }
    }
  }
}
