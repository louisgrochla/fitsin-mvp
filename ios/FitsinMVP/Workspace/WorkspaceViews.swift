import PhotosUI
import SwiftUI

struct WorkspaceRoot: View {
  @StateObject private var model = WorkspaceModel()
  @StateObject private var printer = StickerPrinter()
  @Environment(\.scenePhase) private var phase
  @State private var server =
    (Bundle.main.object(forInfoDictionaryKey: "WORKSPACE_API_URL") as? String) ?? ""
  @State private var invite = ""
  @State private var signingIn = false
  @State private var tab = 0
  var body: some View {
    Group {
      if model.opening {
        ProgressView("Opening saved workspace…").accessibilityLabel("Opening saved workspace")
      } else if model.session != nil && !model.locked {
        TabView(selection: $tab) {
          NavigationStack { WorkspaceToday() }.tabItem { Label("Today", systemImage: "sun.max") }
            .tag(0)
          NavigationStack { WorkspaceStock() }.tabItem { Label("Stock", systemImage: "tshirt") }
            .tag(1)
          NavigationStack { WorkspaceCapture() }.tabItem {
            Label("Capture", systemImage: "viewfinder")
          }.tag(2)
          NavigationStack { WorkspaceSales() }.tabItem { Label("Sales", systemImage: "chart.bar") }
            .tag(3)
          NavigationStack { WorkspaceWork() }.tabItem { Label("Work", systemImage: "tray.full") }
            .tag(4)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
          if let notice = model.notice {
            HStack {
              Image(systemName: model.online ? "exclamationmark.circle" : "wifi.slash")
              Text(notice).font(.caption)
              Spacer()
              Button("Retry") { model.retryPending() }
            }.padding(10).background(.yellow.opacity(0.15))
          }
        }
      } else {
        NavigationStack {
          Form {
            Section {
              Text("Your shop, in your pocket").font(.title2.bold())
              Text(
                "Sign in with your own staff invitation. Stock and work queues belong to the shared business."
              ).foregroundStyle(.secondary)
            }
            Section("Connect to your workspace") {
              TextField("Workspace address", text: $server).textContentType(.URL).keyboardType(.URL)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
              SecureField("Staff invitation", text: $invite).textContentType(.oneTimeCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
              Button {
                signingIn = true
                Task {
                  await model.enroll(originText: server, invitation: invite)
                  signingIn = false
                }
              } label: {
                if signingIn { ProgressView() } else { Text("Sign in on this phone") }
              }.disabled(signingIn || invite.isEmpty)
            }
            if let notice = model.notice { Section { Text(notice).foregroundStyle(.secondary) } }
            if model.locked {
              Button("Close this session") { Task { await model.signOut(revoke: false) } }
            }
          }.navigationTitle("Fit’s In")
        }
      }
    }.environmentObject(model).environmentObject(printer).environment(\.nativeWorkspace, model)
      .tint(Color(red: 0.2, green: 0.32, blue: 0.25))
      .task { model.startSync() }
      .task(id: model.session?.scope) {
        while !Task.isCancelled {
          try? await Task.sleep(for: .seconds(15))
          if phase == .active { model.startSync() }
        }
      }
      .onChange(of: phase) { _, phase in if phase == .active { model.startSync() } }
  }
}
struct WorkspaceToday: View {
  @EnvironmentObject var model: WorkspaceModel
  var body: some View {
    List {
      Section {
        Text(model.session?.actor.businessName ?? "Your shop").font(.title2.bold())
        Text("Hello, \(model.session?.actor.actorName ?? "")").foregroundStyle(.secondary)
        HStack {
          Label(
            model.online ? "Connected" : "Working offline",
            systemImage: model.online ? "wifi" : "wifi.slash")
          Spacer()
          Text("\(model.pendingCount) to sync").monospacedDigit()
        }.font(.caption)
        if let date = model.snapshot.lastRefresh {
          Text("Stock checked \(date.formatted(date:.omitted,time:.shortened))").font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Section("Next up") {
        NavigationLink {
          WorkspaceCapture()
        } label: {
          WorkCount(
            title: "Accepted tags", symbol: "viewfinder",
            count: model.snapshot.scans.filter { !$0.discarded && $0.itemId == nil }.count)
        }
        NavigationLink {
          WorkspaceStock(initialFilter: "draft")
        } label: {
          WorkCount(
            title: "Finish drafts", symbol: "square.and.pencil",
            count: model.snapshot.items.filter { $0.status == "draft" }.count)
        }
        NavigationLink {
          WorkspacePrintQueue()
        } label: {
          WorkCount(
            title: "Print and attach stickers", symbol: "printer",
            count: model.snapshot.prints.filter { !$0.attached }.count)
        }
        NavigationLink {
          WorkspaceStock(initialFilter: "attention")
        } label: {
          WorkCount(
            title: "Listings need attention", symbol: "exclamationmark.bubble",
            count: model.snapshot.items.filter { needsWork($0) }.count)
        }
        NavigationLink {
          WorkspaceSyncQueue()
        } label: {
          WorkCount(
            title: "Saved work and conflicts", symbol: "arrow.triangle.2.circlepath",
            count: model.pendingCount)
        }
      }
      Section("Daily work") {
        NavigationLink("Sales, targets and manual entries") { LegacyToday() }
        NavigationLink("Calendar and rota") { LegacyEvents() }
        NavigationLink("Staff payouts") { SellerSalesView() }
      }
    }.navigationTitle("Today").refreshable { await model.refresh() }
  }
}
private struct WorkCount: View {
  let title: String, symbol: String, count: Int
  var body: some View {
    HStack {
      Label(title, systemImage: symbol)
      Spacer()
      Text("\(count)").font(.headline).monospacedDigit().foregroundStyle(.secondary)
    }
  }
}
private func needsWork(_ item: WItem) -> Bool {
  item.fields["doubleSale"] == .bool(true) || item.status == "pending_manual"
    || item.listings.contains {
      ["failed", "manual_pending", "delist_queued"].contains($0["status"].string ?? "")
    }
}
struct WorkspaceStock: View {
  @EnvironmentObject var model: WorkspaceModel
  @State private var query = ""
  @State private var filter: String
  @State private var created: WItem?
  @State private var createdID: String?
  @State private var destinationID: String?
  init(initialFilter: String = "all") { _filter = State(initialValue: initialFilter) }
  var items: [WItem] {
    model.snapshot.items.filter { item in
      (filter == "all" || (filter == "attention" ? needsWork(item) : item.status == filter))
        && (query.isEmpty
          || [item.sku, item.title, item.text("brand"), item.text("tagSize")].joined(separator: " ")
            .localizedCaseInsensitiveContains(query))
    }
  }
  var body: some View {
    List {
      Section {
        NavigationLink {
          WorkspaceBarcodeCapture(locationID: nil, stocktakeID: nil)
        } label: {
          Label("Find item by barcode", systemImage: "barcode.viewfinder")
        }
        Picker("Show", selection: $filter) {
          Text("All stock").tag("all")
          Text("Drafts").tag("draft")
          Text("Active").tag("active")
          Text("Needs attention").tag("attention")
          Text("Sold").tag("closed")
          Text("Archived").tag("archived")
        }
      }
      ForEach(items) { item in
        NavigationLink {
          WorkspaceItemDetail(itemID: item.id)
        } label: {
          StockRow(item: item)
        }
      }
      if items.isEmpty {
        ContentUnavailableView(
          query.isEmpty ? "No stock here yet" : "No matching garments", systemImage: "tshirt",
          description: Text(
            query.isEmpty
              ? "Scan tags or add a draft to get started."
              : "Try the SKU, description, brand or size."))
      }
    }.navigationTitle("Stock").searchable(text: $query, prompt: "SKU, description, brand, size")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Add", systemImage: "plus") {
            do {
              created = try model.createDraft()
              createdID = created?.id
            } catch {
              model.notice = error.localizedDescription
              model.reserveSKUs()
            }
          }
        }
      }
      .sheet(item: $created, onDismiss: { destinationID = createdID }) { item in
        NavigationStack { WorkspaceItemEditor(item: item) }
      }
      .navigationDestination(item: $destinationID) { WorkspaceItemDetail(itemID: $0) }
      .refreshable { await model.refresh() }
  }
}
struct StockRow: View {
  @EnvironmentObject var model: WorkspaceModel
  let item: WItem
  var body: some View {
    HStack(spacing: 12) {
      StockPhoto(item: item, photo: item.photos.first).frame(width: 55, height: 66).clipShape(
        RoundedRectangle(cornerRadius: 8))
      VStack(alignment: .leading, spacing: 4) {
        Text(item.title.isEmpty ? "Untitled garment" : item.title).font(.headline).lineLimit(2)
        Text("\(item.sku) · \(item.text("tagSize"))").font(.caption).foregroundStyle(.secondary)
        HStack {
          Text(item.status.replacingOccurrences(of: "_", with: " ").capitalized)
          if model.snapshot.commands.contains(where: { $0.itemId == item.id }) {
            Text("· Saved on phone")
          }
        }.font(.caption2).foregroundStyle(.secondary)
      }
      Spacer()
      Text(item.money("tagPrice")).font(.subheadline.bold())
    }.padding(.vertical, 3)
  }
}
struct StockPhoto: View {
  @EnvironmentObject var model: WorkspaceModel
  let item: WItem, photo: WValue?
  @State private var image: UIImage?
  var body: some View {
    Group {
      if let image {
        Image(uiImage: image).resizable().scaledToFill()
      } else {
        ZStack {
          Color.secondary.opacity(0.12)
          Image(systemName: "tshirt").foregroundStyle(.secondary)
        }
      }
    }.clipped().task(id: photo?["id"].string) {
      image = nil
      if let photo, let data = try? await model.photoData(item, photo: photo) {
        image = await Task.detached(priority: .utility) { WPhotoPreparation.thumbnail(data) }.value
      }
    }
  }
}
struct WorkspaceItemDetail: View {
  @EnvironmentObject var model: WorkspaceModel
  let itemID: String
  @State private var editing = false
  @State private var pendingAction: String?
  @State private var channel = "vinted"
  @State private var photos: [PhotosPickerItem] = []
  @State private var importing = false
  @State private var camera = false
  var item: WItem? { model.item(itemID) }
  var body: some View {
    Group {
      if let item {
        List {
          Section {
            StockRow(item: item)
            if !item.photos.isEmpty {
              ScrollView(.horizontal) {
                HStack {
                  ForEach(item.photos.indices, id: \.self) { i in
                    StockPhoto(item: item, photo: item.photos[i]).frame(width: 160, height: 190)
                      .clipShape(RoundedRectangle(cornerRadius: 12))
                  }
                }
              }
            }
          }
          Section("Garment photographs") {
            PhotosPicker(
              selection: $photos, maxSelectionCount: max(1, 30 - item.photos.count),
              matching: .images
            ) { Label("Add from photo library", systemImage: "photo.on.rectangle") }.disabled(
              importing)
            Button("Take garment photo", systemImage: "camera") { camera = true }.disabled(
              !UIImagePickerController.isSourceTypeAvailable(.camera) || importing)
            if importing { ProgressView("Saving photographs…") }
            if !item.photos.isEmpty {
              NavigationLink("Order or remove photos") { WorkspacePhotoOrder(item: item) }
            }
          }
          Section("Stock details") {
            LabeledContent("In-store price", value: item.money("tagPrice"))
            LabeledContent("Online price", value: item.money("listPrice"))
            LabeledContent("Cost", value: item.money("costPrice"))
            ForEach(
              [
                ("Brand", "brand"), ("Size", "size"), ("Condition", "condition"),
                ("Colour", "colour"), ("Material", "material"), ("Fit", "fit"), ("Style", "style"),
              ], id: \.1
            ) { label, key in
              if !item.text(key).isEmpty { LabeledContent(label, value: item.text(key)) }
            }
            if !item.text("description").isEmpty { Text(item.text("description")) }
            Button("Edit garment") { editing = true }
          }
          Section("Sticker") {
            Button("Queue full sticker", systemImage: "printer") {
              perform { try model.enqueuePrint(item: item, format: "full") }
            }
            Button("Queue price and barcode strip") {
              perform { try model.enqueuePrint(item: item, format: "strip") }
            }
            NavigationLink("Open print queue") { WorkspacePrintQueue() }
          }
          Section("Channels") {
            ForEach(item.listings.indices, id: \.self) { i in
              let listing = item.listings[i]
              VStack(alignment: .leading) {
                Text((listing["channel"].string ?? "Channel").capitalized).font(.headline)
                Text((listing["status"].string ?? "").replacingOccurrences(of: "_", with: " "))
                if let error = listing["lastError"].string {
                  Text(error).font(.caption).foregroundStyle(.red)
                }
              }
            }
            NavigationLink("Check listing readiness") {
              WorkspaceReadout(title: "Readiness", path: "items/\(item.id)/preflight", key: nil)
            }
            NavigationLink("Vinted handoff") { WorkspaceVinted(item: item) }
            Picker("Channel", selection: $channel) {
              Text("Vinted").tag("vinted")
              Text("eBay").tag("ebay")
              Text("Shopify").tag("shopify")
            }
            if channel != "vinted" {
              action("Publish to channel", "item.publish")
              action("Retry channel", "item.retry")
            } else {
              action("Confirm manually listed", "item.listed")
              action("Confirm manually removed", "item.removed")
            }
            action("Record a sale", "item.sale")
          }
          Section("Item history and status") {
            NavigationLink("History") {
              WorkspaceReadout(title: "History", path: "items/\(item.id)/events", key: "events")
            }
            NavigationLink("Saved answers") { WorkspaceAnswers(item: item) }
            if item.fields["doubleSale"] == .bool(true) {
              Text("Possible double sale: \(item.text("doubleSaleRef"))").foregroundStyle(.red)
              action("Acknowledge resolved double sale", "item.dismiss-conflict")
            }
            action("Pull from sale", "item.pull")
            action("Restore draft", "item.restore")
            action("Delete garment", "item.delete")
            if item.status == "draft" || item.status == "active" {
              NavigationLink("Remove a duplicate garment") { WorkspaceRemoveTwin(twin: item) }
            }
          }
        }.sheet(isPresented: $editing) { NavigationStack { WorkspaceItemEditor(item: item) } }
          .sheet(isPresented: $camera) {
            GarmentCamera { data in
              camera = false
              if let data { Task { await importData([data], item: item) } }
            }
          }
          .onChange(of: photos) { _, value in
            Task {
              var values: [Data] = []
              for photo in value {
                if let data = try? await photo.loadTransferable(type: Data.self) {
                  values.append(data)
                }
              }
              await importData(values, item: item)
              photos = []
            }
          }
      } else {
        ContentUnavailableView("Garment no longer available", systemImage: "tshirt")
      }
    }
    .navigationTitle(item?.sku ?? "Garment").navigationBarTitleDisplayMode(.inline)
    .confirmationDialog(
      actionTitle,
      isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }),
      presenting: pendingAction
    ) { kind in
      Button(actionTitle, role: kind == "item.delete" ? .destructive : nil) {
        if let item {
          perform {
            _ = try model.queue(
              kind, item: item,
              data: [
                "channel": .string(channel),
                "at": .string(ISO8601DateFormatter().string(from: Date())),
              ])
          }
        }
        pendingAction = nil
      }
      Button("Cancel", role: .cancel) { pendingAction = nil }
    } message: { kind in
      Text(
        kind == "item.print-confirm"
          ? "Only confirm after checking the physical sticker."
          : "This action will be saved and sent to your business when connected. The server checks whether the action is allowed."
      )
    }
  }
  private var actionTitle: String {
    switch pendingAction {
    case "item.publish": return "Publish to \(channel.capitalized)?"
    case "item.sale": return "Record sale on \(channel.capitalized)?"
    case "item.delete": return "Delete this garment?"
    case "item.pull": return "Pull this garment from sale?"
    default: return "Confirm this action?"
    }
  }
  private func action(_ title: String, _ kind: String) -> some View {
    Button(title, role: kind == "item.delete" ? .destructive : nil) { pendingAction = kind }
  }
  private func perform(_ body: () throws -> Void) {
    do { try body() } catch { model.notice = error.localizedDescription }
  }
  private func importData(_ data: [Data], item: WItem) async {
    importing = true
    defer { importing = false }
    do {
      let prepared = try await Task.detached(priority: .userInitiated) {
        try data.map { try WPhotoPreparation.prepare($0) }
      }.value
      try model.addPhotos(item: item, originals: prepared)
    } catch { model.notice = error.localizedDescription }
  }
}
struct WorkspaceItemEditor: View {
  @EnvironmentObject var model: WorkspaceModel
  @Environment(\.dismiss) private var dismiss
  @State var item: WItem
  let commit: ((WItem) throws -> Void)?
  @State private var prices: [String: String]
  @State private var dimensions: [String: String]
  @State private var error: String?
  init(item: WItem, commit: ((WItem) throws -> Void)? = nil) {
    _item = State(initialValue: item)
    self.commit = commit
    _prices = State(
      initialValue: Dictionary(
        uniqueKeysWithValues: ["tagPrice", "listPrice", "costPrice"].map {
          ($0, item.fields[$0]?.int.map { String(format: "%.2f", Double($0) / 100) } ?? "")
        }))
    _dimensions = State(
      initialValue: Dictionary(
        uniqueKeysWithValues: ["chest", "length", "pitToPit"].map { key in
          if case .number(let value) = item.fields["measurements"]?[key] {
            return (key, String(value))
          }
          return (key, "")
        }))
  }
  var body: some View {
    Form {
      Section("Shop tag") {
        field("Description", "tagItem")
        field("Size on tag", "tagSize")
        money("In-store price", "tagPrice")
        field("Condition on tag", "tagCondition")
      }
      Section("Listing") {
        field("Title", "title")
        field("Description and wear", "description", axis: .vertical)
        field("Brand", "brand")
        field("Size", "size")
        field("Label wording", "sizeLabel")
        field("Condition", "condition")
        field("Colour", "colour")
        field("Material", "material")
        field("Garment type", "garmentType")
        field("Era", "era")
        field("Fit", "fit")
        field("Style", "style")
        field("Keywords", "keywords", axis: .vertical)
        money("Online price", "listPrice")
        money("Cost price", "costPrice")
      }
      Section("Measurements in inches") {
        measurement("Chest", "chest")
        measurement("Length", "length")
        measurement("Pit to pit", "pitToPit")
      }
      Section("Channel choices") {
        NavigationLink("Choose saved Vinted options") { WorkspaceVintedChoices(item: $item) }
        NavigationLink("Previously used eBay categories") { WorkspaceEbayCategories(item: $item) }
      }
      Section("eBay category") {
        field("Category ID", "ebayCategoryId")
        field("Category name", "ebayCategoryName")
      }
      Section {
        LabeledContent("SKU", value: item.sku)
        Text("Rail assignment is optional and can be done later.").font(.caption).foregroundStyle(
          .secondary)
      }
      if let error { Text(error).foregroundStyle(.red) }
    }.navigationTitle("Edit garment").toolbar {
      ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          do {
            var edited = item
            for (key, text) in prices {
              edited.fields[key] =
                try WEntryParsing.money(text).map { .number(Double($0)) } ?? .null
            }
            var measurements = edited.fields["measurements"]?.object ?? [:]
            for (key, text) in dimensions {
              if text.isEmpty {
                measurements.removeValue(forKey: key)
              } else {
                guard let value = Double(text), value >= 0, value <= 200 else {
                  throw WError.message("Measurements must be between 0 and 200 inches")
                }
                measurements[key] = .number(value)
              }
            }
            edited.fields["measurements"] = .object(measurements)
            if let commit { try commit(edited) } else { try model.save(edited) }
            dismiss()
          } catch { self.error = error.localizedDescription }
        }
      }
    }
  }
  private func field(_ name: String, _ key: String, axis: Axis = .horizontal) -> some View {
    TextField(
      name, text: Binding(get: { item.text(key) }, set: { item.fields[key] = .string($0) }),
      axis: axis)
  }
  private func money(_ name: String, _ key: String) -> some View {
    LabeledContent(name) {
      TextField("£", text: Binding(get: { prices[key] ?? "" }, set: { prices[key] = $0 }))
        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
    }
  }
  private func measurement(_ name: String, _ key: String) -> some View {
    LabeledContent(name) {
      TextField("in", text: Binding(get: { dimensions[key] ?? "" }, set: { dimensions[key] = $0 }))
        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
    }
  }
}
