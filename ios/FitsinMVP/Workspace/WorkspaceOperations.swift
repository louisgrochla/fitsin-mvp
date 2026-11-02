import SwiftUI

struct WorkspaceReviews: View {
  @EnvironmentObject var model: WorkspaceModel
  @State private var reviews: [WValue] = []
  @State private var error: String?
  var body: some View {
    List {
      ForEach(reviews.indices, id: \.self) { i in
        let review = reviews[i]
        if let itemId = review["itemId"].string, let item = model.item(itemId) {
          NavigationLink {
            WorkspaceAnswer(review: review, item: item)
          } label: {
            VStack(alignment: .leading) {
              Text(review["aspect"].string ?? "Question").font(.headline)
              Text("\(item.sku) · \(item.title)")
              Text(review["internalValue"].string ?? "No answer yet").font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
      if reviews.isEmpty && error == nil {
        ContentUnavailableView("No questions waiting", systemImage: "checkmark.bubble")
      }
      if let error { Text(error) }
    }.navigationTitle("Questions").task { await load() }.refreshable { await load() }
  }
  private func load() async {
    do {
      reviews = try await model.read("reviews")["reviews"].array
      error = nil
    } catch { self.error = error.localizedDescription }
  }
}
struct WorkspaceAnswer: View {
  @EnvironmentObject var model: WorkspaceModel
  @Environment(\.dismiss) private var dismiss
  let review: WValue, item: WItem
  @State private var answer = ""
  var body: some View {
    Form {
      Section {
        Text(item.title)
        Text(review["aspect"].string ?? "Question").font(.headline)
        Text("Current wording: \(review["internalValue"].string ?? "Not set")")
      }
      Section("Your answer") {
        if review["constrained"] == .bool(true) {
          Picker("Choose", selection: $answer) {
            Text("Choose an answer").tag("")
            ForEach(review["allowedValues"].array.compactMap(\.string), id: \.self) {
              Text($0).tag($0)
            }
          }
        } else {
          TextField("Answer", text: $answer)
        }
      }
      Button("Save answer") {
        do {
          _ = try model.queue(
            "item.answer", item: item,
            data: ["reviewId": review["id"], "externalValue": .string(answer)])
          dismiss()
        } catch { model.notice = error.localizedDescription }
      }.disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }.navigationTitle("Answer question")
  }
}
struct WorkspaceAnswers: View {
  @EnvironmentObject var model: WorkspaceModel
  let item: WItem
  @State private var answers: [WValue] = []
  @State private var error: String?
  var body: some View {
    List {
      ForEach(answers.indices, id: \.self) { i in
        let answer = answers[i]
        VStack(alignment: .leading) {
          Text(answer["aspect"].string ?? "Answer").font(.headline)
          Text(answer["externalValue"].string ?? "")
          Button("Forget this answer") {
            do {
              _ = try model.queue(
                "item.forget-answer", item: item, data: ["reviewId": answer["id"]])
              answers.remove(at: i)
            } catch { self.error = error.localizedDescription }
          }
        }
      }
      if answers.isEmpty { Text("No saved answers") }
      if let error { Text(error) }
    }.navigationTitle("Saved answers").task {
      do { answers = try await model.read("items/\(item.id)/answers")["answers"].array } catch {
        self.error = error.localizedDescription
      }
    }
  }
}
struct WorkspaceMappings: View {
  @EnvironmentObject var model: WorkspaceModel
  @State private var mappings: [WValue] = []
  @State private var error: String?
  var body: some View {
    List {
      Section {
        Text(
          "Shared vocabulary and this business’s corrections. Forgetting an answer affects only this business and reopens its matching questions."
        ).font(.caption)
      }
      ForEach(mappings.indices, id: \.self) { i in
        let row = mappings[i]
        if row["externalValue"] != .null {
          VStack(alignment: .leading) {
            Text(row["aspect"].string ?? "Mapping").font(.headline)
            Text("\(row["internalValue"].string ?? "") → \(row["externalValue"].string ?? "")")
            Text("Category \(row["categoryId"].string ?? "")").font(.caption)
            Button("Forget mapping") {
              do {
                _ = try model.queue("mapping.forget", data: ["mappingId": row["id"]])
                mappings.remove(at: i)
              } catch { self.error = error.localizedDescription }
            }
          }
        }
      }
      if let error { Text(error) }
    }.navigationTitle("Mappings").task { await load() }.refreshable { await load() }
  }
  private func load() async {
    do { mappings = try await model.read("mappings")["mappings"].array } catch {
      self.error = error.localizedDescription
    }
  }
}
struct WorkspaceBacklog: View {
  @EnvironmentObject var model: WorkspaceModel
  @State private var scans: [WValue] = []
  @State private var error: String?
  var body: some View {
    List {
      ForEach(scans.indices, id: \.self) { i in
        let scan = scans[i]
        NavigationLink {
          WorkspaceBacklogReview(scan: scan)
        } label: {
          Text("Tag from \(scan["shotAt"].string ?? scan["createdAt"].string ?? "backlog")")
        }
      }
      if scans.isEmpty { Text("No tag photographs waiting") }
      if let error { Text(error) }
    }.navigationTitle("Scan backlog").task { await load() }.refreshable { await load() }
  }
  private func load() async {
    do { scans = try await model.read("scans")["scans"].array } catch {
      self.error = error.localizedDescription
    }
  }
}
struct WorkspaceBacklogReview: View {
  @EnvironmentObject var model: WorkspaceModel
  let scan: WValue
  @State private var image: UIImage?
  @State private var selected = ""
  @State private var editing: WItem?
  @State private var error: String?
  var body: some View {
    Form {
      if let image { Image(uiImage: image).resizable().scaledToFit() }
      Text(
        "Review this tag, then choose or create its garment. Linking the tag keeps it separate from garment photographs and does not put stock on sale."
      ).font(.caption)
      Button("Create a draft from this tag") {
        do {
          let item = try model.createDraft()
          selected = item.id
          editing = item
        } catch {
          self.error = error.localizedDescription
          model.reserveSKUs()
        }
      }
      Picker("Garment", selection: $selected) {
        Text("Choose garment").tag("")
        ForEach(model.snapshot.items) { Text("\($0.sku) · \($0.title)").tag($0.id) }
      }
      Button("Link reviewed tag") {
        guard let item = model.item(selected) else { return }
        do {
          _ = try model.queue("item.backlog-link", item: item, data: ["scanId": scan["id"]])
        } catch { self.error = error.localizedDescription }
      }.disabled(selected.isEmpty)
      Button("Discard tag photograph", role: .destructive) {
        do { _ = try model.queue("backlog.discard", data: ["scanId": scan["id"]]) } catch {
          self.error = error.localizedDescription
        }
      }
      if let error { Text(error) }
    }.navigationTitle("Review tag").sheet(item: $editing) { item in
      NavigationStack { WorkspaceItemEditor(item: item) }
    }.task {
      do {
        guard let api = model.api, let id = scan["id"].string else { return }
        image = UIImage(data: try await api.request("/native/v1/read/scans/\(id)/image"))
      } catch { self.error = error.localizedDescription }
    }
  }
}
struct WorkspaceLocations: View {
  @EnvironmentObject var model: WorkspaceModel
  @State private var name = ""
  @State private var kind = "rail"
  @State private var parent = ""
  @State private var error: String?
  var data: WValue { model.snapshot.locations }
  var locations: [WValue] { data["locations"].array }
  var body: some View {
    List {
      Section {
        Text("Optional places for stock. You can list and sell a garment without assigning a rail.")
          .font(.caption)
      }
      Section("Locations") {
        ForEach(locations.indices, id: \.self) { i in
          let location = locations[i]
          NavigationLink {
            WorkspaceLocation(location: location)
          } label: {
            Label(location["name"].string ?? "Location", systemImage: "mappin.and.ellipse")
          }
        }
      }
      Section("Add a location") {
        TextField("Name", text: $name)
        Picker("Type", selection: $kind) {
          Text("Rail").tag("rail")
          Text("Shelf").tag("shelf")
          Text("Box").tag("box")
          Text("Area").tag("area")
        }
        Picker("Parent", selection: $parent) {
          Text("None").tag("")
          ForEach(locations.filter { $0["parentId"] == .null }, id: \.self) {
            Text($0["name"].string ?? "Location").tag($0["id"].string ?? "")
          }
        }
        Button("Save location") {
          do {
            _ = try model.queue(
              "location.save",
              data: [
                "id": .string(UUID().uuidString), "name": .string(name), "kind": .string(kind),
                "parentId": .text(parent), "expectedRevision": .number(0),
              ])
            name = ""
          } catch { self.error = error.localizedDescription }
        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      Section("Stocktakes") {
        ForEach(data["stocktakes"].array.indices, id: \.self) { i in
          let take = data["stocktakes"].array[i]
          NavigationLink {
            WorkspaceStocktake(takeID: take["id"].string ?? "")
          } label: {
            VStack(alignment: .leading) {
              Text(locations.first { $0["id"] == take["locationId"] }?["name"].string ?? "Location")
              Text(take["completedAt"] == .null ? "In progress" : "Completed").font(.caption)
            }
          }
        }
      }
      if let error { Text(error) }
    }.navigationTitle("Rails and stocktake").refreshable { await model.refresh() }
  }
}
struct WorkspaceLocation: View {
  @EnvironmentObject var model: WorkspaceModel
  let location: WValue
  @State private var selected = Set<String>()
  @State private var editing = false
  @State private var startedTake: String?
  @State private var query = ""
  @State private var error: String?
  var body: some View {
    List {
      Section {
        Text(
          "Select the garments you are assigning. Existing garments stay assigned unless you select and move them."
        ).font(.caption)
        NavigationLink("Scan barcodes to assign garments") {
          WorkspaceBarcodeCapture(locationID: location["id"].string, stocktakeID: nil)
        }
        Button("Edit location") { editing = true }
        Button("Assign selected (\(selected.count))") { assign() }.disabled(selected.isEmpty)
        Button("Clear assignment for selected") { assign(clear: true) }.disabled(selected.isEmpty)
        Button("Start stocktake snapshot") {
          do { startedTake = try model.queue("stocktake.start", data: ["locationId": location["id"]]) } catch
          { self.error = error.localizedDescription }
        }
      }
      Section("Garments") {
        ForEach(
          model.snapshot.items.filter {
            query.isEmpty || ($0.sku + " " + $0.title).localizedCaseInsensitiveContains(query)
          }
        ) { item in
          Button {
            if selected.contains(item.id) {
              selected.remove(item.id)
            } else {
              selected.insert(item.id)
            }
          } label: {
            HStack {
              Image(systemName: selected.contains(item.id) ? "checkmark.circle.fill" : "circle")
              VStack(alignment: .leading) {
                Text("\(item.sku) · \(item.title)")
                if item.fields["locationId"] == location["id"] {
                  Text("Assigned here").font(.caption)
                }
              }
            }
          }
        }
      }
      Section("Recent moves") {
        ForEach(
          model.snapshot.locations["moves"].array.filter { $0["toId"] == location["id"] },
          id: \.self
        ) { move in
          if let item = model.item(move["itemId"].string ?? "") {
            Button("Undo assignment of \(item.sku)") {
              do {
                _ = try model.queue("item.location-undo", item: item, data: ["moveId": move["id"]])
              } catch { self.error = error.localizedDescription }
            }
          }
        }
      }
      if let error { Text(error) }
    }.sheet(isPresented: $editing) {
      NavigationStack {
        WorkspaceLocationEditor(
          location: model.snapshot.locations["locations"].array.first { $0["id"] == location["id"] }
            ?? location)
      }
    }.navigationDestination(item: $startedTake) { WorkspaceStocktake(takeID: $0) }
    .navigationTitle(location["name"].string ?? "Location").searchable(
      text: $query, prompt: "Find garments")
  }
  private func assign(clear: Bool = false) {
    do {
      for id in selected.sorted() {
        if let item = model.item(id) {
          _ = try model.queue("item.location", item: item, data: ["locationId": clear ? .null : location["id"]])
        }
      }
      selected = []
    } catch { self.error = error.localizedDescription }
  }
}
struct WorkspaceStocktake: View {
  @EnvironmentObject var model: WorkspaceModel
  let takeID: String
  @State private var sku = ""
  @State private var error: String?
  var take: WValue {
    model.snapshot.locations["stocktakes"].array.first { $0["id"].string == takeID } ?? .null
  }
  var body: some View {
    List {
      Section {
        Text(
          "Observations record what you found. Missing garments are never marked sold or removed. Moves, edits and sales since the snapshot remain visible."
        ).font(.caption)
      }
      if take == .null {
        Section {
          Text("Your stocktake is saved on this phone. Its expected stock snapshot will appear after syncing.")
          NavigationLink("View saved work") { WorkspaceSyncQueue() }
        }
      } else if take["completedAt"] == .null {
        Section("Record an observation") {
          TextField("SKU", text: $sku).textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
          NavigationLink("Scan garment barcodes") {
            WorkspaceBarcodeCapture(locationID: nil, stocktakeID: takeID)
          }
          Button("Record garment seen") { observe() }
            .disabled(sku.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          Button("Complete stocktake") {
            do {
              _ = try model.queue("stocktake.complete", data: ["stocktakeId": .string(takeID)])
            } catch { self.error = error.localizedDescription }
          }
        }
      } else {
        Label("Stocktake completed", systemImage: "checkmark.circle")
      }
      Section("Snapshot results") {
        ForEach(take["expected"].array, id: \.self) { row in
          HStack {
            Text(row["sku"].string ?? "Garment")
            Spacer()
            Text(row["result"].string ?? "").foregroundStyle(.secondary)
          }
        }
      }
      Section("Unexpected observations") {
        ForEach(take["unexpected"].array, id: \.self) { row in
          Text(row["item"]["sku"].string ?? "Removed garment")
        }
      }
      Section("Saved on this phone") {
        ForEach(
          model.snapshot.commands.filter {
            $0.kind == "stocktake.observe" && $0.data["stocktakeId"] == .string(takeID)
          }
        ) { command in Text(model.item(command.data["itemId"]?.string ?? "")?.sku ?? "Observation")
        }
      }
      if let error { Text(error) }
    }.navigationTitle("Stocktake").refreshable { await model.refresh() }
  }
  private func observe() {
    guard
      let item = model.snapshot.items.first(where: {
        $0.sku.caseInsensitiveCompare(sku.trimmingCharacters(in: .whitespacesAndNewlines))
          == .orderedSame
      })
    else {
      error = "No matching garment in this workspace"
      return
    }
    do {
      _ = try model.queue(
        "stocktake.observe", data: ["stocktakeId": .string(takeID), "itemId": .string(item.id)])
      sku = ""
      error = nil
    } catch { self.error = error.localizedDescription }
  }
}

struct WorkspaceChannelSettings: View {
  @EnvironmentObject var model: WorkspaceModel
  @State private var channels: [WValue] = []
  @State private var selected: WValue?
  @State private var error: String?
  var body: some View {
    List {
      Section {
        Text(
          "These settings apply to the shared business. Existing provider connections stay on the server."
        ).font(.caption)
      }
      ForEach(channels, id: \.self) { channel in
        VStack(alignment: .leading, spacing: 8) {
          Text((channel["channel"].string ?? "Channel").capitalized).font(.headline)
          Text(
            "\(channel["mode"].string ?? "") · \(channel["enabled"] == .bool(true) ? "Enabled" : "Disabled")"
          )
          Button(channel["enabled"] == .bool(true) ? "Disable channel" : "Enable channel") {
            selected = channel
          }
        }
      }
      if let error { Text(error).foregroundStyle(.red) }
    }.navigationTitle("Channels").task(id: model.pendingCount) { await load() }.refreshable { await load() }
      .confirmationDialog(
        "Change this channel for the business?",
        isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }),
        presenting: selected
      ) { channel in
        Button("Save channel setting") {
          do {
            _ = try model.queue(
              "channel.set-enabled",
              data: [
                "channel": channel["channel"], "expectedEnabled": channel["enabled"],
                "enabled": .bool(channel["enabled"] != .bool(true)),
              ])
          } catch { self.error = error.localizedDescription }
        }
      } message: { _ in
        Text(
          "Enabling an existing connection allows its ordinary listing and sync work to run. Disabling it does not remove existing live listings."
        )
      }
  }
  private func load() async {
    do { channels = try await model.read("me")["channels"].array } catch {
      self.error = error.localizedDescription
    }
  }
}

struct WorkspaceBarcodeCapture: View {
  @EnvironmentObject var model: WorkspaceModel
  @Environment(\.scenePhase) private var phase
  @StateObject private var scanner = LiveTagScanner()
  let locationID: String?, stocktakeID: String?
  @State private var destination: String?
  @State private var found: WItem?
  @State private var seen = Set<String>()
  var findMode: Bool { locationID == nil && stocktakeID == nil }
  var locationName: String {
    model.snapshot.locations["locations"].array.first {
      $0["id"].string == (destination ?? locationID)
    }?["name"].string ?? "Location"
  }
  var saved: Set<String> {
    Set(
      model.snapshot.commands.filter {
        stocktakeID != nil
          ? $0.data["stocktakeId"]?.string == stocktakeID
          : ($0.kind == "item.location"
            && $0.data["locationId"]?.string == (destination ?? locationID))
      }.compactMap { $0.itemId ?? $0.data["itemId"]?.string })
  }
  var body: some View {
    VStack(spacing: 16) {
      if !findMode {
        Text(stocktakeID == nil ? "Destination: \(locationName)" : "Stocktake observations").font(
          .headline)
        Text("\(saved.union(seen).count) unique garments saved in this batch").font(.caption)
      }
      TagCameraPreview(scanner: scanner).clipShape(RoundedRectangle(cornerRadius: 16))
      Text(scanner.message).font(.headline)
      Text(
        findMode
          ? "Scan the garment’s exact SKU to open its saved stock record."
          : stocktakeID == nil
            ? "Only scanned garments move. A LOC: marker selects another destination."
            : "Observations do not move stock or mark unobserved garments sold."
      ).font(.caption)
      Button(scanner.torchOn ? "Turn torch off" : "Turn torch on") { scanner.toggleTorch() }
    }.padding().navigationTitle(
      findMode ? "Find item" : stocktakeID == nil ? "Assign garments" : "Observe garments"
    )
    .navigationDestination(item: $found) { WorkspaceItemDetail(itemID: $0.id) }
    .task { start() }.onDisappear { scanner.stop() }.onChange(of: phase) { _, phase in
      if phase == .active { start() } else { scanner.stop() }
    }
  }
  private func start() {
    scanner.startBarcodes { sku in
      if sku.hasPrefix("LOC:"), !findMode, stocktakeID == nil {
        let id = String(sku.dropFirst(4))
        guard model.snapshot.locations["locations"].array.contains(where: { $0["id"].string == id })
        else { throw WError.message("Unknown location marker") }
        destination = id
        seen = []
        return
      }
      guard let item = model.snapshot.items.first(where: { $0.sku == sku }) else {
        throw WError.message("\(sku) is not in this business’s saved stock")
      }
      if findMode {
        found = item
        scanner.stop()
        return
      }
      if saved.contains(item.id) || seen.contains(item.id) { return }
      if let stocktakeID {
        _ = try model.queue(
          "stocktake.observe",
          data: [
            "stocktakeId": .string(stocktakeID), "itemId": .string(item.id),
            "source": .string("barcode"),
          ])
      } else if let destination = destination ?? locationID {
        _ = try model.queue(
          "item.location", item: item,
          data: ["locationId": .string(destination), "source": .string("barcode")])
      }
      seen.insert(item.id)
    }
  }
}

struct WorkspaceLocationEditor: View {
  @EnvironmentObject var model: WorkspaceModel
  @Environment(\.dismiss) private var dismiss
  let location: WValue
  @State private var name: String
  @State private var kind: String
  @State private var parent: String
  @State private var error: String?
  init(location: WValue) {
    self.location = location
    _name = State(initialValue: location["name"].string ?? "")
    _kind = State(initialValue: location["kind"].string ?? "rail")
    _parent = State(initialValue: location["parentId"].string ?? "")
  }
  var body: some View {
    Form {
      TextField("Name", text: $name)
      Picker("Type", selection: $kind) {
        ForEach(["rail", "shelf", "box", "area"], id: \.self) { Text($0.capitalized).tag($0) }
      }
      Picker("Parent", selection: $parent) {
        Text("None").tag("")
        ForEach(
          model.snapshot.locations["locations"].array.filter {
            $0["parentId"] == .null && $0["id"] != location["id"]
          }, id: \.self
        ) {
          Text($0["name"].string ?? "Location").tag($0["id"].string ?? "")
        }
      }
      Section("Stable marker") {
        Text("LOC:\(location["id"].string ?? "")").font(.caption.monospaced()).textSelection(
          .enabled)
        Text("The ID stays the same when this location is renamed or moved.").font(.caption)
      }
      if let error { Text(error).foregroundStyle(.red) }
      Button("Save location") {
        do {
          _ = try model.queue(
            "location.save",
            data: [
              "id": location["id"], "expectedRevision": location["revision"], "name": .string(name),
              "kind": .string(kind), "parentId": .text(parent),
            ])
          dismiss()
        } catch { self.error = error.localizedDescription }
      }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }.navigationTitle("Edit location").toolbar { Button("Cancel") { dismiss() } }
  }
}

struct WorkspaceRemoveTwin: View {
  @EnvironmentObject var model: WorkspaceModel
  @Environment(\.dismiss) private var dismiss
  let twin: WItem
  @State private var kept: WItem?
  @State private var query = ""
  @State private var confirm = false
  @State private var error: String?
  var body: some View {
    List {
      Section {
        Text("Remove duplicate \(twin.sku)").font(.headline)
        Text(
          "Choose the real garment to keep. The duplicate is archived and its Shopify product is queued for deletion. Marketplace listings must be taken down first. Review both SKUs carefully."
        ).font(.caption)
      }
      ForEach(
        model.snapshot.items.filter {
          $0.id != twin.id && ["draft", "active"].contains($0.status)
            && (query.isEmpty || ($0.sku + " " + $0.title).localizedCaseInsensitiveContains(query))
        }
      ) { item in
        Button {
          kept = item
          confirm = true
        } label: {
          StockRow(item: item)
        }
      }
      if let error { Text(error).foregroundStyle(.red) }
    }.navigationTitle("Keep which garment?").searchable(text: $query)
      .confirmationDialog("Keep \(kept?.sku ?? "") and remove \(twin.sku)?", isPresented: $confirm)
    {
      Button("Remove duplicate", role: .destructive) {
        guard let kept else { return }
        do {
          _ = try model.queue(
            "item.remove-twin", item: twin,
            data: ["keptItemId": .string(kept.id), "keptRevision": .number(Double(kept.revision))])
          dismiss()
        } catch { self.error = error.localizedDescription }
      }
    }
  }
}
