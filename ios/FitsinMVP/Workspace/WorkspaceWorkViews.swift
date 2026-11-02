import PhotosUI
import SwiftUI

struct WorkspaceCapture: View {
  @EnvironmentObject var model: WorkspaceModel
  @StateObject private var scanner = LiveTagScanner()
  @Environment(\.scenePhase) private var phase
  @State private var scanning = false
  @State private var manual = false
  @State private var edit: WItem?
  @State private var createdID: String?
  @State private var destinationID: String?
  var body: some View {
    List {
      Section {
        if scanning {
          TagCameraPreview(scanner: scanner).frame(height: 330).clipShape(
            RoundedRectangle(cornerRadius: 14))
          Text(scanner.message).font(.headline).accessibilityAddTraits(.updatesFrequently)
          if let candidate = scanner.candidate {
            Text(
              "\(candidate.description) · \(candidate.size) · \(String(format:"£%.2f",Double(candidate.price)/100))"
            ).font(.caption)
          }
          Button(scanner.torchOn ? "Turn torch off" : "Turn torch on") { scanner.toggleTorch() }
          Text("Tap the camera view to focus.").font(.caption)
          Button("Pause camera") {
            scanner.stop()
            scanning = false
          }
        } else {
          Button("Start live tag reader", systemImage: "viewfinder") {
            scanning = true
            startCamera()
          }
        }
        Text(
          "Clear, stable readings save automatically. Unclear prices stay for review. Scanning never publishes or activates stock."
        ).font(.caption).foregroundStyle(.secondary)
        Button("Enter or review a tag manually", systemImage: "square.and.pencil") { manual = true }
      }
      Section(
        "Accepted tags · \(model.snapshot.scans.filter{!$0.discarded && $0.itemId==nil}.count)"
      ) {
        ForEach(model.snapshot.scans.filter { !$0.discarded && $0.itemId == nil }) { scan in
          VStack(alignment: .leading, spacing: 8) {
            Text(scan.description).font(.headline)
            Text(
              "\(scan.size) · \(scan.price.map{String(format:"£%.2f",Double($0)/100)} ?? "Price needs review")"
            ).foregroundStyle(.secondary)
            Button("Make draft") {
              do {
                edit = try model.createDraft(scan: scan)
                createdID = edit?.id
              } catch {
                model.notice = error.localizedDescription
                model.reserveSKUs()
              }
            }
          }.swipeActions {
            Button("Discard", role: .destructive) {
              do { try model.discardScan(scan) } catch { model.notice = error.localizedDescription }
            }
          }
        }
        if model.snapshot.scans.filter({ !$0.discarded && $0.itemId == nil }).isEmpty {
          Text("Your saved tags will appear here, including offline.").foregroundStyle(.secondary)
        }
      }
      Section {
        LabeledContent("Reserved SKU numbers", value: String(model.availableSKUs))
        Button("Reserve more numbers") { model.reserveSKUs() }
      }
      NavigationLink("Existing scan backlog") { WorkspaceBacklog() }
    }.navigationTitle("Capture").sheet(isPresented: $manual) {
      NavigationStack { ManualTagEntry(reading: scanner.candidate) }
    }
    .sheet(item: $edit, onDismiss: { destinationID = createdID }) { item in
      NavigationStack { WorkspaceItemEditor(item: item) }
    }
    .navigationDestination(item: $destinationID) { WorkspaceItemDetail(itemID: $0) }
    .onDisappear {
      scanner.stop()
      scanning = false
    }
    .onChange(of: phase) { _, phase in
      if phase != .active {
        scanner.stop()
        scanning = false
      }
    }
  }
  private func startCamera() { scanner.start { try model.accept($0) } }
}
struct ManualTagEntry: View {
  @EnvironmentObject var model: WorkspaceModel
  @Environment(\.dismiss) private var dismiss
  @State private var description: String
  @State private var size: String
  @State private var price: String
  @State private var error: String?
  init(reading: TagReading?) {
    _description = State(initialValue: reading?.description ?? "")
    _size = State(initialValue: reading?.size ?? "")
    _price = State(
      initialValue: reading.map { String(format: "%.2f", Double($0.price) / 100) } ?? "")
  }
  var body: some View {
    Form {
      TextField("Tag description", text: $description, axis: .vertical)
      TextField("Size", text: $size)
      TextField("Price in pounds", text: $price).keyboardType(.decimalPad)
      if let error { Text(error).foregroundStyle(.red) }
    }.navigationTitle("Review tag").toolbar {
      ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      ToolbarItem(placement: .confirmationAction) {
        Button("Accept") {
          do {
            let pence = try WEntryParsing.money(price)
            guard description.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2,
              description.count <= 200, size.count <= 30,
              price.isEmpty || (pence != nil && pence! >= 0 && pence! <= 1_000_000)
            else { throw WError.message("Check the description, size and price") }
            try model.accept(WScan(description: description, size: size, price: pence))
            dismiss()
          } catch { self.error = error.localizedDescription }
        }
      }
    }
  }
}
struct WorkspaceWork: View {
  @EnvironmentObject var model: WorkspaceModel
  var body: some View {
    List {
      Section("Queues") {
        NavigationLink("Saved work and conflicts (\(model.pendingCount))") { WorkspaceSyncQueue() }
        NavigationLink("Stickers to print or attach") { WorkspacePrintQueue() }
        NavigationLink("Listings and removals") { WorkspaceStock(initialFilter: "attention") }
        NavigationLink("Questions to answer") { WorkspaceReviews() }
        NavigationLink("Scan backlog") { WorkspaceBacklog() }
      }
      Section("Business") {
        NavigationLink("Mappings") { WorkspaceMappings() }
        NavigationLink("Deleted item history") {
          WorkspaceReadout(title: "Deleted history", path: "deleted", key: "deleted")
        }
        NavigationLink("Channel settings") {
          WorkspaceChannelSettings()
        }
        if model.session?.actor.locationsEnabled == true {
          NavigationLink("Rails and stocktake") { WorkspaceLocations() }
        }
      }
      Section("Staff and daily work") {
        NavigationLink("Calendar and rota") { LegacyEvents() }
        NavigationLink("Staff payouts") { SellerSalesView() }
        NavigationLink("App settings") { SettingsView() }
      }
      Section("This device") {
        Text(model.session?.actor.actorName ?? "")
        Text(model.session?.actor.businessName ?? "")
        Button("Sync saved work") { model.retryPending() }
        LabeledContent("SKU numbers available", value: String(model.availableSKUs))
        Button("Reserve SKU numbers") { model.reserveSKUs() }
        Button("Sign out") { Task { await model.signOut(revoke: false) } }
        Button("Revoke and sign out this device", role: .destructive) {
          Task { await model.signOut(revoke: true) }
        }
        Text(
          "Signing out retains unsent work for the same staff identity on this phone. Revocation needs a connection."
        ).font(.caption).foregroundStyle(.secondary)
      }
    }.navigationTitle("Work")
  }
}
struct WorkspaceSyncQueue: View {
  @EnvironmentObject var model: WorkspaceModel
  var body: some View {
    List {
      if model.snapshot.commands.isEmpty {
        ContentUnavailableView("Everything is synced", systemImage: "checkmark.icloud")
      }
      ForEach(model.snapshot.commands) { command in
        VStack(alignment: .leading, spacing: 6) {
          Text(
            command.kind.replacingOccurrences(of: "item.", with: "").replacingOccurrences(
              of: ".", with: " "
            ).capitalized
          ).font(.headline)
          if let id = command.itemId, let item = model.item(id) {
            Text("\(item.sku) · \(item.title)")
          }
          Text(
            command.state == "blocked"
              ? "Needs review" : (command.state == "sending" ? "Syncing" : "Saved on phone")
          ).font(.caption).foregroundStyle(.secondary)
          if let failure = command.failure { Text(failure).font(.caption) }
          if command.state == "blocked", command.itemId != nil {
            NavigationLink("Review saved change") { WorkspaceConflict(command: command) }
          }
        }
      }
    }.navigationTitle("Saved work").toolbar { Button("Retry") { model.retryPending() } }
  }
}
struct WorkspaceConflict: View {
  @EnvironmentObject var model: WorkspaceModel
  @Environment(\.dismiss) private var dismiss
  let command: WCommand
  @State private var current: WValue?
  @State private var error: String?
  @State private var confirm = false
  var body: some View {
    List {
      Section {
        Text(
          "Your saved change has not been applied. Compare it with the current garment before choosing to apply it again."
        )
      }
      Section("Your saved change") {
        ForEach(command.data.keys.sorted(), id: \.self) { key in
          if !["id", "photos"].contains(key) {
            LabeledContent(friendly(key), value: displayField(key, command.data[key] ?? .null))
          }
        }
      }
      if let current {
        Section("Current garment") {
          ForEach(command.data.keys.sorted(), id: \.self) { key in
            if !["id", "photos"].contains(key) {
              LabeledContent(friendly(key), value: displayField(key, current[key]))
            }
          }
        }
      }
      if let error { Text(error).foregroundStyle(.red) }
      if command.kind == "item.save", let revision = current?["revision"].int {
        NavigationLink("Edit the saved garment before retrying") {
          WorkspaceItemEditor(item: WItem(fields: command.data)) { edited in
            model.resolveUsingCurrent(command, reviewedRevision: revision, editedData: edited.input)
          }
        }
      }
      Button("Apply my saved change after review") { confirm = true }.disabled(current == nil)
    }.navigationTitle("Resolve conflict")
      .onChange(of: model.snapshot.commands.contains(where: { $0.id == command.id })) { _, exists in
        if !exists { dismiss() }
      }.task {
        do { current = try await model.read("items/\(command.itemId ?? "")") } catch {
          self.error = error.localizedDescription
        }
      }
      .confirmationDialog("Apply your saved change to the current garment?", isPresented: $confirm)
    {
      Button("Apply saved change") {
        if let revision = current?["revision"].int {
          model.resolveUsingCurrent(command, reviewedRevision: revision)
        }
      }
    } message: {
      Text(
        "A new change will be created. Later edits from other staff can still cause another conflict."
      )
    }
  }
}
struct WorkspacePrintQueue: View {
  @EnvironmentObject var model: WorkspaceModel
  @EnvironmentObject var printer: StickerPrinter
  @State private var preview: UIImage?
  var body: some View {
    List {
      Section("Printer") {
        Text(printer.status)
        Button("Find nearby printers") { printer.scan() }
        ForEach(printer.devices) { device in
          Button {
            printer.connect(device)
          } label: {
            VStack(alignment: .leading) {
              Text(device.name)
              Text(device.id.uuidString).font(.caption2)
            }
          }
        }
      }
      ForEach(model.snapshot.prints.reversed()) { job in
        Section {
          Text("\(job.item.sku) · \(job.item.title)").font(.headline)
          Text("\(job.format.capitalized) · \(job.state.capitalized)").foregroundStyle(.secondary)
          if let failure = job.failure { Text(failure).font(.caption).foregroundStyle(.orange) }
          Button("Preview sticker") {
            do { preview = try M02Protocol.render(item: job.item, format: job.format).0 } catch {
              model.notice = error.localizedDescription
            }
          }
          if job.state == "queued" {
            Button("Print this sticker") { Task { await printer.printJob(job, model: model) } }
              .disabled(printer.busy)
          }
          if ["inspect", "uncertain"].contains(job.state) {
            Text(
              "Check the physical sticker, including its price and barcode. Confirming records the print, activates a draft and queues its till listing if Shopify is enabled. Bluetooth acknowledgement alone does not prove it printed."
            ).font(.caption)
            Button("Sticker printed correctly") { perform { try model.confirmPrint(job.id) } }
            Button("Needs reprint — add another copy") {
              perform {
                try model.enqueuePrint(item: job.item, format: job.format)
                try model.setPrint(job.id, state: "replaced")
              }
            }
          }
          if job.state == "confirmed" {
            if job.attached {
              Label("Attached to garment", systemImage: "checkmark.circle.fill")
            } else {
              Button("Mark attached to garment") { perform { try model.attachPrint(job.id) } }
            }
          }
        }
      }
      if model.snapshot.prints.isEmpty {
        ContentUnavailableView(
          "No stickers queued", systemImage: "printer",
          description: Text("Open a garment to add a full sticker or a price strip."))
      }
    }.navigationTitle("Stickers").sheet(
      isPresented: Binding(get: { preview != nil }, set: { if !$0 { preview = nil } })
    ) {
      if let preview {
        NavigationStack {
          ScrollView {
            Image(uiImage: preview).interpolation(.none).resizable().scaledToFit().padding()
          }.navigationTitle("Sticker preview").toolbar { Button("Done") { self.preview = nil } }
        }
      }
    }
  }
  private func perform(_ body: () throws -> Void) {
    do { try body() } catch { model.notice = error.localizedDescription }
  }
}
struct WorkspaceReadout: View {
  @EnvironmentObject var model: WorkspaceModel
  let title: String, path: String, key: String?
  @State private var data: WValue?
  @State private var error: String?
  var body: some View {
    List {
      if let data {
        let value = key.map { data[$0] } ?? data
        ReadableValue(value: value)
      } else if error == nil {
        ProgressView()
      }
      if let error { Text(error).foregroundStyle(.secondary) }
    }.navigationTitle(title).task { await load() }.refreshable { await load() }
  }
  private func load() async {
    do {
      data = try await model.read(path)
      error = nil
    } catch { self.error = error.localizedDescription }
  }
}
private struct ReadableValue: View {
  let value: WValue
  var body: some View {
    Group {
      switch value {
      case .array(let list):
        if list.isEmpty {
          Text("Nothing to show").foregroundStyle(.secondary)
        } else {
          ForEach(list.indices, id: \.self) { i in
            Section { ReadableObject(values: list[i].object) }
          }
        }
      case .object(let object): ReadableObject(values: object)
      default: Text(display(value))
      }
    }
  }
}
private struct ReadableObject: View {
  let values: [String: WValue]
  var body: some View {
    ForEach(
      values.keys.sorted().filter { !($0 == "id" || $0.hasSuffix("Id") || $0 == "metadata") },
      id: \.self
    ) { key in
      if case .array(let rows) = values[key] {
        ForEach(rows.indices, id: \.self) { i in Text(display(rows[i])) }
      } else {
        LabeledContent(friendly(key), value: displayField(key, values[key] ?? .null))
      }
    }
  }
}
func friendly(_ key: String) -> String {
  key.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
    .replacingOccurrences(of: "_", with: " ").capitalized
}
func displayField(_ key: String, _ value: WValue) -> String {
  if key.lowercased().contains("price"), case .number(let pence) = value {
    return String(format: "£%.2f", pence / 100)
  }
  return display(value)
}
func display(_ value: WValue) -> String {
  switch value {
  case .string(let s): return s
  case .number(let n): return n.formatted()
  case .bool(let b): return b ? "Yes" : "No"
  case .null: return "Not set"
  case .array(let a): return a.map(display).joined(separator: ", ")
  case .object(let o):
    return o.keys.sorted().map { "\(friendly($0)): \(display(o[$0]!))" }.joined(separator: "\n")
  }
}

struct LegacyToday: View {
  @StateObject private var vm = TodayViewModel()
  @StateObject private var rota = RotaViewModel()
  var body: some View { TodayView(vm: vm, rotaVM: rota) }
}
struct LegacyEvents: View {
  @StateObject private var vm = EventsViewModel()
  var body: some View { EventsView(vm: vm) }
}
struct LegacyMonth: View {
  @StateObject private var vm = MonthViewModel()
  var body: some View { MonthView(vm: vm) }
}
struct WorkspaceSales: View {
  @EnvironmentObject var model: WorkspaceModel
  var body: some View {
    List {
      Section("Sales and targets") {
        NavigationLink("Today’s sales and manual entries") { LegacyToday() }
        NavigationLink("Month and history") { LegacyMonth() }
        NavigationLink("Staff payouts") { SellerSalesView() }
      }
      Section("Sold garments") {
        ForEach(model.snapshot.items.filter { !$0.text("soldAt").isEmpty }) { item in
          NavigationLink {
            WorkspaceItemDetail(itemID: item.id)
          } label: {
            VStack(alignment: .leading) {
              StockRow(item: item)
              Text("\(item.text("soldChannel").capitalized) · \(item.text("soldAt"))").font(
                .caption)
            }
          }
        }
        Text(
          "Garment sale status comes from Crosstopher. Revenue, commission and payouts remain in the sales records above."
        ).font(.caption).foregroundStyle(.secondary)
      }
    }.navigationTitle("Sales")
  }
}
