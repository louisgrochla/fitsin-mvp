import SwiftUI

private struct NativeWorkspaceKey: EnvironmentKey { static let defaultValue: WorkspaceModel? = nil }
extension EnvironmentValues {
  var nativeWorkspace: WorkspaceModel? {
    get { self[NativeWorkspaceKey.self] }
    set { self[NativeWorkspaceKey.self] = newValue }
  }
}
struct WorkspaceSaleLink: View {
  @ObservedObject var model: WorkspaceModel
  let sku: String, shop: String
  @State private var itemID: String?
  var body: some View {
    Group {
      if let itemID, let item = model.item(itemID) {
        NavigationLink {
          WorkspaceItemDetail(itemID: itemID)
        } label: {
          HStack {
            StockPhoto(item: item, photo: item.photos.first).frame(width: 35, height: 42).clipShape(
              RoundedRectangle(cornerRadius: 5))
            Label("Open \(item.sku)", systemImage: "tshirt")
          }.font(.caption)
        }
      } else {
        Text("\(sku) · stock link unverified").font(.caption2).foregroundStyle(.secondary)
      }
    }.task(id: "\(model.session?.scope ?? "")|\(shop)|\(sku)") {
      itemID = nil
      guard let api = model.api, !model.locked else { return }
      let scope = model.session?.scope
      var components = URLComponents()
      components.queryItems = [
        URLQueryItem(name: "shop", value: shop), URLQueryItem(name: "sku", value: sku),
      ]
      if let query = components.percentEncodedQuery,
        let result = try? await api.value("/native/v1/sales-link?" + query),
        model.session?.scope == scope
      {
        itemID = result["itemId"].string
      }
    }
  }
}
