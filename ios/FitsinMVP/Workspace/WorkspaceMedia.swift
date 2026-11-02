import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct GarmentCamera: UIViewControllerRepresentable {
  let completion: (Data?) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(completion) }
  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.cameraCaptureMode = .photo
    picker.delegate = context.coordinator
    return picker
  }
  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
  final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate
  {
    let completion: (Data?) -> Void
    init(_ completion: @escaping (Data?) -> Void) { self.completion = completion }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) { completion((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 1)) }
  }
}
struct WorkspacePhotoOrder: View {
  @EnvironmentObject var model: WorkspaceModel
  @Environment(\.dismiss) private var dismiss
  @State var item: WItem
  var body: some View {
    List {
      ForEach(item.photos.indices, id: \.self) { i in
        HStack {
          StockPhoto(item: item, photo: item.photos[i]).frame(width: 70, height: 80)
          Text(i == 0 ? "Cover photograph" : "Photograph \(i+1)")
        }
      }.onMove { source, destination in
        var photos = item.photos
        photos.move(fromOffsets: source, toOffset: destination)
        set(photos)
      }.onDelete { source in
        var photos = item.photos
        photos.remove(atOffsets: source)
        set(photos)
      }
    }.environment(\.editMode, .constant(.active)).navigationTitle("Photographs").toolbar {
      Button("Save") {
        do {
          try model.save(item)
          dismiss()
        } catch { model.notice = error.localizedDescription }
      }
    }
  }
  private func set(_ photos: [WValue]) {
    item.fields["photos"] = .array(
      photos.enumerated().map { index, photo in
        var fields = photo.object
        fields["ordinal"] = .number(Double(index))
        return .object(fields)
      })
  }
}
struct WorkspaceVinted: View {
  @EnvironmentObject var model: WorkspaceModel
  let item: WItem
  @State private var payload: WValue?
  @State private var error: String?
  @State private var share: [Any] = []
  @State private var sharing = false
  @State private var loading = false
  var body: some View {
    List {
      Section {
        Text(
          "Review and submit in Vinted yourself. Confirm listed only after Vinted shows the garment live."
        ).font(.subheadline)
      }
      if let payload {
        Section("Listing text") {
          Text(payload["title"].string ?? item.title).font(.headline)
          Text(payload["description"].string ?? "").textSelection(.enabled)
          Button("Copy title") { UIPasteboard.general.string = payload["title"].string }
          Button("Copy description") { UIPasteboard.general.string = payload["description"].string }
          LabeledContent("Price", value: payload["price"].string ?? "Not set")
        }
        Section("Photos") {
          Button(loading ? "Preparing photographs…" : "Share listing and photographs") {
            Task { await prepareShare() }
          }.disabled(loading)
          Text(
            "Choose Save Images or your preferred sharing destination. Check the order and cover before submitting."
          ).font(.caption)
        }
        Section("After submitting") {
          Button("Confirm listed on Vinted") {
            do {
              _ = try model.queue("item.listed", item: item, data: ["channel": .string("vinted")])
            } catch { self.error = error.localizedDescription }
          }
        }
      }
      if let error { Text(error).foregroundStyle(.red) }
    }.navigationTitle("Vinted handoff").task {
      do { payload = try await model.read("items/\(item.id)/vinted-payload") } catch {
        self.error = error.localizedDescription
      }
    }.sheet(isPresented: $sharing) { NativeShare(items: share) }
  }
  private func prepareShare() async {
    loading = true
    defer { loading = false }
    do {
      var values: [Any] = [
        payload?["title"].string ?? item.title, payload?["description"].string ?? "",
      ]
      for photo in item.photos.prefix(20) {
        let bytes = try await model.photoData(item, photo: photo)
        guard let image = UIImage(data: bytes) else {
          throw WError.message("One photograph could not be loaded")
        }
        values.append(image)
      }
      share = values
      sharing = true
    } catch { self.error = error.localizedDescription }
  }
}
struct NativeShare: UIViewControllerRepresentable {
  let items: [Any]
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct WorkspaceEbayCategories: View {
  @EnvironmentObject var model: WorkspaceModel
  @Environment(\.dismiss) private var dismiss
  @Binding var item: WItem
  @State private var options: [WValue] = []
  @State private var error: String?
  var body: some View {
    List {
      ForEach(options, id: \.self) { option in
        Button(option["name"].string ?? option["id"].string ?? "Category") {
          item.fields["ebayCategoryId"] = option["id"]
          item.fields["ebayCategoryName"] = option["name"]
          dismiss()
        }
      }
      if options.isEmpty {
        Text("No previous categories. You can enter the exact category in the garment editor.")
      }
      if let error { Text(error) }
    }.navigationTitle("eBay categories").task {
      do { options = try await model.read("ebay/categories/used")["categories"].array } catch {
        self.error = error.localizedDescription
      }
    }
  }
}
struct WorkspaceVintedChoices: View {
  @EnvironmentObject var model: WorkspaceModel
  @Binding var item: WItem
  @State private var options: [WValue] = []
  @State private var query = ""
  @State private var error: String?
  let fields = [
    ("catalog", "catalogId", "Category"), ("brand", "brandId", "Brand"), ("size", "sizeId", "Size"),
    ("condition", "conditionId", "Condition"), ("colour", "colourIds", "Colours"),
    ("material", "materialIds", "Materials"), ("package", "packageType", "Package"),
  ]
  var selection: [String: WValue] { item.fields["vinted"]?.object ?? [:] }
  var body: some View {
    List {
      Section {
        Text(
          "Choose from vocabulary already learned by Crosstopher. Check the choices in Vinted when you submit. New provider vocabulary is still learned through its existing desktop workflow."
        ).font(.caption)
      }
      ForEach(fields, id: \.0) { kind, key, title in
        Section(title) {
          ForEach(
            options.filter { option in
              option["kind"].string == kind
                && (query.isEmpty
                  || (option["label"].string ?? "").localizedCaseInsensitiveContains(query))
                && (!["size", "material"].contains(kind)
                  || (option["scopeCatalogId"].string ?? "").isEmpty
                  || option["scopeCatalogId"] == selection["catalogId"])
            }, id: \.self
          ) { option in
            let value = option["vintedId"]
            let multiple = key.hasSuffix("Ids")
            let chosen =
              multiple ? (selection[key]?.array.contains(value) ?? false) : selection[key] == value
            Button {
              var next = selection
              if multiple {
                var values = next[key]?.array ?? []
                if chosen {
                  values.removeAll { $0 == value }
                } else if values.count < (key == "colourIds" ? 4 : 6) {
                  values.append(value)
                }
                next[key] = .array(values)
              } else {
                next[key] = chosen ? .null : value
                if key == "catalogId" {
                  next["sizeId"] = .null
                  next["materialIds"] = .array([])
                }
              }
              item.fields["vinted"] = .object(next)
            } label: {
              Label(
                option["label"].string ?? "Option",
                systemImage: chosen ? "checkmark.circle.fill" : "circle")
            }
          }
        }
      }
      if options.isEmpty {
        Text(
          "No saved vocabulary yet. The garment’s ordinary description and sizes are still available for human submission."
        )
      }
      if let error { Text(error) }
    }.navigationTitle("Vinted choices").searchable(text: $query).task {
      do { options = try await model.read("vinted/taxonomy")["options"].array } catch {
        self.error = error.localizedDescription
      }
    }
  }
}
