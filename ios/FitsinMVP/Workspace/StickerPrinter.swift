import CoreBluetooth
import CoreImage
import Foundation
import SwiftUI
import UIKit

enum M02Protocol {
  static let width = 384
  static let initialize = Data([0x1b, 0x40, 0x1b, 0x61, 0x01, 0x1f, 0x11, 0x02, 0x04])
  static let park = Data([
    0x1b, 0x64, 0x02, 0x1b, 0x64, 0x02, 0x1f, 0x11, 0x08, 0x1f, 0x11, 0x0e, 0x1f, 0x11, 0x07, 0x1f,
    0x11, 0x09,
  ])
  static func raster(_ pixels: [UInt8], height: Int) throws -> [Data] {
    guard height > 0, pixels.count == width * height else {
      throw WError.message("Invalid sticker raster")
    }
    var data = initialize
    for row in stride(from: 0, to: height, by: 255) {
      let rows = min(255, height - row)
      data.append(contentsOf: [0x1d, 0x76, 0x30, 0, 48, 0, UInt8(rows & 255), UInt8(rows >> 8)])
      for y in row..<(row + rows) {
        for byte in 0..<48 {
          var bits: UInt8 = 0
          for bit in 0..<8 where pixels[y * width + byte * 8 + bit] < 160 { bits |= 1 << (7 - bit) }
          data.append(bits)
        }
      }
    }
    data.append(park)
    return stride(from: 0, to: data.count, by: 128).map {
      Data(data[$0..<min($0 + 128, data.count)])
    }
  }
  static func render(item: WItem, format: String) throws -> (UIImage, [Data]) {
    let height = format == "strip" ? 184 : 640
    guard let filter = CIFilter(name: "CICode128BarcodeGenerator") else {
      throw WError.message("Barcode encoder unavailable")
    }
    filter.setValue(Data(item.sku.utf8), forKey: "inputMessage")
    filter.setValue(0, forKey: "inputQuietSpace")
    guard let code = filter.outputImage,
      let barcode = CIContext().createCGImage(code, from: code.extent)
    else { throw WError.message("SKU cannot be encoded") }
    let scale = min(4, (width - 32 - 32) / barcode.width)
    guard scale >= 2 else {
      throw WError.message("This SKU is too long for a readable 384-dot sticker")
    }
    let rendererFormat = UIGraphicsImageRendererFormat()
    rendererFormat.scale = 1
    rendererFormat.opaque = true
    let image = UIGraphicsImageRenderer(
      size: CGSize(width: width, height: height), format: rendererFormat
    ).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(x: 0, y: 0, width: width, height: height))
      UIColor.black.setFill()
      func label(
        _ text: String, _ rect: CGRect, _ size: CGFloat, _ weight: UIFont.Weight = .regular
      ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        (text as NSString).draw(
          in: rect,
          withAttributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph,
          ])
      }
      let barcodeY: CGFloat
      if format == "strip" {
        label(
          "\(item.money("tagPrice"))     \(item.text("tagSize"))",
          CGRect(x: 16, y: 8, width: 352, height: 55), 32, .bold)
        barcodeY = 72
      } else {
        label("FIT’S IN", CGRect(x: 16, y: 20, width: 352, height: 45), 30, .bold)
        label(item.title, CGRect(x: 16, y: 80, width: 352, height: 172), 30, .semibold)
        label(item.text("tagSize"), CGRect(x: 16, y: 260, width: 352, height: 60), 42, .bold)
        label(item.money("tagPrice"), CGRect(x: 16, y: 330, width: 352, height: 80), 58, .bold)
        label(item.text("tagCondition"), CGRect(x: 16, y: 420, width: 352, height: 72), 22)
        barcodeY = 510
      }
      let barcodeWidth = barcode.width * scale
      let rect = CGRect(
        x: (width - barcodeWidth) / 2, y: Int(barcodeY), width: barcodeWidth,
        height: format == "strip" ? 70 : 78)
      context.cgContext.interpolationQuality = .none
      context.cgContext.saveGState()
      context.cgContext.translateBy(x: rect.minX, y: rect.maxY)
      context.cgContext.scaleBy(x: 1, y: -1)
      context.cgContext.draw(barcode, in: CGRect(origin: .zero, size: rect.size))
      context.cgContext.restoreGState()
      label(
        item.sku, CGRect(x: 16, y: format == "strip" ? 150 : 596, width: 352, height: 34), 22,
        .medium)
    }
    guard let cg = image.cgImage else { throw WError.message("Sticker render failed") }
    var pixels = [UInt8](repeating: 255, count: width * height)
    guard
      let context = CGContext(
        data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
    else { throw WError.message("Sticker raster unavailable") }
    context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
    return (image, try raster(pixels, height: height))
  }
}
@MainActor
final class StickerPrinter: NSObject, ObservableObject, @preconcurrency CBCentralManagerDelegate,
  @preconcurrency CBPeripheralDelegate
{
  struct Device: Identifiable {
    var id: UUID
    var name: String
    var peripheral: CBPeripheral
  }
  @Published var devices: [Device] = []
  @Published var status = "Choose your M02 printer"
  @Published var connectedName: String?
  @Published var busy = false
  private var central: CBCentralManager!
  private var peripheral: CBPeripheral?
  private var characteristic: CBCharacteristic?
  private var ack: CheckedContinuation<Void, Error>?
  private var ackTimeout: Task<Void, Never>?
  private var generation = UUID()
  override init() { super.init() }
  func scan() {
    if central == nil {
      central = CBCentralManager(delegate: self, queue: .main)
    } else if central.state == .poweredOn {
      devices = []
      central.scanForPeripherals(
        withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
      status = "Searching nearby printers…"
    }
  }
  func connect(_ device: Device) {
    guard !busy else { return }
    central.stopScan()
    if let peripheral { central.cancelPeripheralConnection(peripheral) }
    generation = UUID()
    peripheral = device.peripheral
    characteristic = nil
    peripheral?.delegate = self
    central.connect(device.peripheral)
    status = "Connecting to \(device.name)…"
  }
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state == .poweredOn {
      scan()
    } else {
      characteristic = nil
      connectedName = nil
      status =
        central.state == .unauthorized
        ? "Enable Bluetooth access in iPhone Settings" : "Turn on Bluetooth to print"
      fail(WError.message(status))
    }
  }
  func centralManager(
    _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any], rssi RSSI: NSNumber
  ) {
    guard !devices.contains(where: { $0.id == peripheral.identifier }) else { return }
    let name =
      (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
      ?? "Unnamed Bluetooth device"
    devices.append(Device(id: peripheral.identifier, name: name, peripheral: peripheral))
  }
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    peripheral.discoverServices(nil)
  }
  func centralManager(
    _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
  ) {
    status = error?.localizedDescription ?? "Printer connection failed"
    fail(WError.message(status))
  }
  func centralManager(
    _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
  ) {
    characteristic = nil
    connectedName = nil
    generation = UUID()
    status = "Printer disconnected"
    fail(WError.message(status))
  }
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if let error {
      status = error.localizedDescription
      return
    }
    let supported = Set([
      "FF00", "FF01", "FF02", "FFE0", "FFE5", "FEE7", "18F0", "E0FF", "FF10",
      "49535343-FE7D-4AE5-8FA9-9FAFD205E455",
    ])
    let services = (peripheral.services ?? []).filter {
      supported.contains($0.uuid.uuidString.uppercased())
    }
    if services.isEmpty {
      status = "This device has no supported M02 printing service"
      return
    }
    for service in services { peripheral.discoverCharacteristics(nil, for: service) }
  }
  func peripheral(
    _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
  ) {
    guard error == nil, characteristic == nil else { return }
    if let writable = service.characteristics?.first(where: {
      $0.properties.contains(.writeWithoutResponse) || $0.properties.contains(.write)
    }) {
      characteristic = writable
      connectedName = peripheral.name ?? peripheral.identifier.uuidString
      status = "Ready: \(connectedName!)"
    }
  }
  func peripheral(
    _ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?
  ) {
    ackTimeout?.cancel()
    let waiting = ack
    ack = nil
    if let error { waiting?.resume(throwing: error) } else { waiting?.resume() }
  }
  private func fail(_ error: Error) {
    ackTimeout?.cancel()
    let waiting = ack
    ack = nil
    waiting?.resume(throwing: error)
  }
  func printJob(_ job: WPrintJob, model: WorkspaceModel) async {
    guard !busy, let peripheral, let characteristic, peripheral.state == .connected else {
      status = "Connect your chosen printer first"
      return
    }
    guard job.state == "queued" else {
      status = "Inspect the previous print before requesting a reprint"
      return
    }
    busy = true
    defer { busy = false }
    let current = generation
    let scope = model.session?.scope
    do {
      let (_, chunks) = try M02Protocol.render(item: job.item, format: job.format)
      // Persist before the very first byte, including the init command.
      try model.setPrint(job.id, state: "sending", printer: peripheral.identifier.uuidString)
      let type: CBCharacteristicWriteType =
        characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
      let maximum = min(128, peripheral.maximumWriteValueLength(for: type))
      guard maximum > 0 else { throw WError.message("Printer write size unavailable") }
      for chunk in chunks {
        for offset in stride(from: 0, to: chunk.count, by: maximum) {
          guard generation == current, peripheral.state == .connected, !Task.isCancelled,
            model.session?.scope == scope, !model.locked
          else {
            throw WError.message("Print interrupted")
          }
          let data = Data(chunk[offset..<min(offset + maximum, chunk.count)])
          if type == .withoutResponse {
            let deadline = Date().addingTimeInterval(5)
            while !peripheral.canSendWriteWithoutResponse {
              guard Date() < deadline, generation == current else {
                throw WError.message("Printer stopped accepting data")
              }
              try await Task.sleep(for: .milliseconds(20))
            }
            peripheral.writeValue(data, for: characteristic, type: type)
          } else {
            try await withCheckedThrowingContinuation { continuation in
              ack = continuation
              ackTimeout = Task {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                self.fail(WError.message("Printer acknowledgement timed out"))
              }
              peripheral.writeValue(data, for: characteristic, type: type)
            }
          }
          try await Task.sleep(for: .milliseconds(20))
        }
      }
      try model.setPrint(job.id, state: "inspect")
      status = "Data sent. Check the printed sticker before confirming."
    } catch {
      try? model.setPrint(job.id, state: "uncertain", error: error.localizedDescription)
      status =
        "Print uncertain. Inspect the printer and sticker; nothing will resend automatically."
    }
  }
}
