@preconcurrency import AVFoundation
import Foundation
import SwiftUI
import Vision

struct TagReading: Equatable, Sendable {
  var description: String, size: String, price: Int
  var key: String { "\(description.lowercased())|\(size.lowercased())|\(price)" }
}
struct TagEvidence: Sendable {
  var time: TimeInterval
  var track: CGRect
  var reading: TagReading?
  var confidence: Float
  var sharp: Bool
  var ambiguous: Bool
  var frameFingerprint: UInt64? = nil
}
struct StableTagGate {
  private var candidate: String?
  private var first: TimeInterval = 0
  private var last: TimeInterval = -1
  private var count = 0
  private var rect: CGRect = .zero
  private var accepted = false
  private var missingSince: TimeInterval?
  private var recentFrames: [UInt64] = []
  mutating func observe(_ evidence: TagEvidence) -> TagReading? {
    guard evidence.time > last else { return nil }
    let gap = evidence.time - last
    last = evidence.time
    guard let reading = evidence.reading, !evidence.ambiguous, evidence.sharp,
      evidence.confidence >= 0.85, !evidence.track.isEmpty
    else {
      candidate = nil
      count = 0
      if evidence.track.isEmpty {
        if missingSince == nil { missingSince = evidence.time }
        if evidence.time - (missingSince ?? evidence.time) > 0.8 {
          accepted = false
          rect = .zero
        }
      }
      return nil
    }
    missingSince = nil
    let overlap = rect.intersection(evidence.track)
    let union =
      rect.width * rect.height + evidence.track.width * evidence.track.height - overlap.width
      * overlap.height
    let sameTrack = union > 0 && !overlap.isNull && overlap.width * overlap.height / union > 0.6
    // Rearm only when the tag leaves the scene; changing OCR on the same tag
    // cannot produce two accepted garments.
    if accepted { return nil }
    if candidate != reading.key || !sameTrack || gap > 0.8 {
      candidate = reading.key
      first = evidence.time
      count = 1
      recentFrames = evidence.frameFingerprint.map { [$0] } ?? []
    } else {
      if let fingerprint = evidence.frameFingerprint {
        guard !recentFrames.contains(fingerprint) else { return nil }
        recentFrames.append(fingerprint)
        if recentFrames.count > 12 { recentFrames.removeFirst() }
      }
      count += 1
    }
    rect = evidence.track
    guard count >= 5, evidence.time - first >= 1.5 else { return nil }
    accepted = true
    return reading
  }
  mutating func acceptanceFailed() {
    accepted = false
    candidate = nil
    count = 0
  }
}
enum TagParser {
  static func parse(_ lines: [String]) -> (TagReading?, Bool) {
    let cleaned = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter {
      !$0.isEmpty
    }
    let text = cleaned.joined(separator: "\n")
    let pricePattern =
      #"(?:£\s*|(?:PRICE|Price|price)\s*:?\s*£?\s*)(\d{1,4}(?:[.,]\d{2})?)(?![\p{L}\d.,])"#
    guard let regex = try? NSRegularExpression(pattern: pricePattern) else { return (nil, true) }
    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    guard matches.count == 1, let range = Range(matches[0].range(at: 1), in: text),
      let decimal = Decimal(string: String(text[range]).replacingOccurrences(of: ",", with: "."))
    else { return (nil, matches.count > 1) }
    let money = NSDecimalNumber(decimal: decimal * 100).intValue
    guard money > 0, money <= 1_000_000 else { return (nil, true) }
    let sizePattern =
      #"(?i)^(?:size\s*:?\s*)?(XXS|XS|S|M|L|XL|XXL|XXXL|[2-5]XL|\d{1,2}(?:\s*[-/]\s*\d{1,2})?)$"#
    let sizes = cleaned.filter { $0.range(of: sizePattern, options: .regularExpression) != nil }
    guard sizes.count == 1 else { return (nil, sizes.count > 1) }
    let size = sizes[0].replacingOccurrences(
      of: #"(?i)^size\s*:?\s*"#, with: "", options: .regularExpression)
    let excluded = #"(?i)^(size|price|condition|fits.?in|sku)\s*:?$"#
    let descriptions = cleaned.filter {
      !sizes.contains($0) && $0.range(of: pricePattern, options: .regularExpression) == nil
        && $0.range(of: excluded, options: .regularExpression) == nil
        && $0.range(of: #"^[A-Z]{1,4}-\d{4,}$"#, options: .regularExpression) == nil
    }
    let description = descriptions.joined(separator: " ")
    guard description.count >= 4, description.count <= 200,
      description.rangeOfCharacter(from: .letters) != nil
    else { return (nil, false) }
    let ambiguous =
      text.contains("?") || text.contains("~~") || text.localizedCaseInsensitiveContains("was ")
      || text.contains("→")
    return (TagReading(description: description, size: size, price: money), ambiguous)
  }
}
@MainActor
final class LiveTagScanner: NSObject, ObservableObject {
  @Published var message = "Point at one tag in good light"
  @Published var running = false
  @Published var boxes: [CGRect] = []
  @Published var candidate: TagReading?
  @Published var acceptedCount = 0
  @Published var torchOn = false
  let capture = AVCaptureSession()
  private let queue = DispatchQueue(label: "fitsin.camera.vision", qos: .userInitiated)
  private var delegate: TagFrameDelegate?
  private var gate = StableTagGate()
  private var onAccept: ((WScan) throws -> Void)?
  private var lastAccepted: TagReading?
  private var cameraTicket = UUID()
  private var barcodeAction: ((String) throws -> Void)?
  func start(onAccept: @escaping (WScan) throws -> Void) {
    self.onAccept = onAccept
    barcodeAction = nil
    begin()
  }
  func startBarcodes(onBarcode: @escaping (String) throws -> Void) {
    barcodeAction = onBarcode
    onAccept = nil
    begin()
  }
  private func begin() {
    let ticket = UUID()
    cameraTicket = ticket
    Task {
      let granted = await AVCaptureDevice.requestAccess(for: .video)
      guard cameraTicket == ticket else { return }
      guard granted else {
        message = "Camera access is off. Enable it in iPhone Settings, or enter a tag manually."
        return
      }
      guard !running else { return }
      let delegate = TagFrameDelegate(
        barcode: barcodeAction == nil
          ? nil
          : { [weak self] sku, box in
            Task { @MainActor in
              guard let self, self.running, self.cameraTicket == ticket else { return }
              self.boxes = [box]
              do {
                try self.barcodeAction?(sku)
                self.acceptedCount += 1
                self.message = "Read \(sku). Move to the next barcode."
              } catch { self.message = error.localizedDescription }
            }
          }
      ) { [weak self] evidence, boxes, reason in
        Task { @MainActor in self?.receive(evidence, boxes: boxes, reason: reason) }
      }
      self.delegate = delegate
      let session = capture
      queue.async {
        do {
          session.beginConfiguration()
          session.sessionPreset = .hd1280x720
          if session.inputs.isEmpty {
            guard
              let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back)
            else { throw WError.message("Camera unavailable. Use manual entry on Simulator.") }
            let input = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(input) else {
              throw WError.message("Camera input unavailable")
            }
            session.addInput(input)
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
              kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.setSampleBufferDelegate(delegate, queue: self.queue)
            guard session.canAddOutput(output) else {
              throw WError.message("Camera output unavailable")
            }
            session.addOutput(output)
          } else if let output = session.outputs.first as? AVCaptureVideoDataOutput {
            output.setSampleBufferDelegate(delegate, queue: self.queue)
          }
          session.commitConfiguration()
          session.startRunning()
          Task { @MainActor in if self.cameraTicket == ticket { self.running = true } }
        } catch {
          session.commitConfiguration()
          Task { @MainActor in self.message = error.localizedDescription }
        }
      }
    }
  }
  func stop() {
    cameraTicket = UUID()
    torchOn = false
    let session = capture
    queue.async { session.stopRunning() }
    running = false
  }
  func toggleTorch() {
    let turnOn = !torchOn
    let session = capture
    queue.async {
      guard let device = (session.inputs.first as? AVCaptureDeviceInput)?.device,
        device.hasTorch
      else { return }
      do {
        try device.lockForConfiguration()
        device.torchMode = turnOn ? .on : .off
        device.unlockForConfiguration()
        Task { @MainActor in self.torchOn = turnOn }
      } catch { Task { @MainActor in self.message = "Torch unavailable" } }
    }
  }
  func focus(at point: CGPoint) {
    let session = capture
    queue.async {
      guard let device = (session.inputs.first as? AVCaptureDeviceInput)?.device else {
        return
      }
      do {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if device.isFocusPointOfInterestSupported {
          device.focusPointOfInterest = point
          if device.isFocusModeSupported(.autoFocus) { device.focusMode = .autoFocus }
        }
        if device.isExposurePointOfInterestSupported {
          device.exposurePointOfInterest = point
          if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
          }
        }
      } catch {}
    }
  }
  private func receive(_ evidence: TagEvidence, boxes: [CGRect], reason: String) {
    guard running else { return }
    self.boxes = boxes
    candidate = evidence.reading
    if let reading = gate.observe(evidence) {
      do {
        try onAccept?(
          WScan(description: reading.description, size: reading.size, price: reading.price))
        acceptedCount += 1
        lastAccepted = reading
        message = "Saved. Move to the next tag."
        UIAccessibility.post(notification: .announcement, argument: "Tag saved")
      } catch {
        gate.acceptanceFailed()
        message = "Not saved: \(error.localizedDescription)"
      }
    } else {
      message =
        lastAccepted == evidence.reading
        ? "Saved. Move the tag out of view before scanning another." : reason
    }
  }
}
private final class TagFrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,
  @unchecked Sendable
{
  let deliver: (TagEvidence, [CGRect], String) -> Void
  private var last: TimeInterval = 0
  private let barcode: ((String, CGRect) -> Void)?
  private var previousBarcode: String?
  private var barcodeFrames = 0
  private var deliveredBarcode: String?
  private var barcodeLastSeen: TimeInterval = 0
  init(
    barcode: ((String, CGRect) -> Void)? = nil,
    deliver: @escaping (TagEvidence, [CGRect], String) -> Void
  ) {
    self.barcode = barcode
    self.deliver = deliver
  }

  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
    guard time - last >= 0.32, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
    last = time
    if let barcode {
      let request = VNDetectBarcodesRequest()
      request.symbologies = [.code128]
      do {
        try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .right, options: [:]).perform(
          [request])
        let codes = request.results ?? []
        guard codes.count == 1, let result = codes.first, let sku = result.payloadStringValue,
          sku.range(
            of: #"^(?:[A-Z]{1,4}-\d{4,}|LOC:[A-Za-z0-9_-]{1,100})$"#, options: .regularExpression)
            != nil
        else {
          if time - barcodeLastSeen > 0.8 {
            deliveredBarcode = nil
            previousBarcode = nil
            barcodeFrames = 0
          }
          return
        }
        barcodeLastSeen = time
        if sku == previousBarcode {
          barcodeFrames += 1
        } else {
          previousBarcode = sku
          barcodeFrames = 1
        }
        if barcodeFrames >= 2, deliveredBarcode == nil {
          deliveredBarcode = sku
          barcode(sku, result.boundingBox)
        }
      } catch {}
      return
    }
    let rectangles = VNDetectRectanglesRequest()
    rectangles.maximumObservations = 3
    rectangles.minimumSize = 0.18
    rectangles.minimumConfidence = 0.7
    rectangles.minimumAspectRatio = 0.25
    let text = VNRecognizeTextRequest()
    text.recognitionLevel = .accurate
    text.usesLanguageCorrection = false
    text.recognitionLanguages = ["en-GB"]
    text.minimumTextHeight = 0.015
    do {
      let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .right, options: [:])
      try handler.perform([rectangles])
      let tags = (rectangles.results ?? []).map(\.boundingBox)
      guard tags.count == 1, let tag = tags.first, tag.minX > 0.02, tag.maxX < 0.98,
        tag.minY > 0.02, tag.maxY < 0.98
      else {
        deliver(
          TagEvidence(
            time: time, track: .zero, confidence: 0, sharp: false, ambiguous: tags.count > 1), tags,
          tags.count > 1 ? "Show one tag at a time" : "Keep the whole tag inside the frame")
        return
      }
      text.regionOfInterest = tag
      try handler.perform([text])
      let observations = (text.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
      let best = observations.compactMap { $0.topCandidates(1).first }
      let (reading, ambiguous) = TagParser.parse(best.map(\.string))
      let confidence = best.map(\.confidence).min() ?? 0
      let alternatives = observations.contains { observation in
        let candidates = observation.topCandidates(2)
        return candidates.count > 1 && candidates[0].string != candidates[1].string
          && candidates[1].confidence > 0.8
          && candidates[0].confidence - candidates[1].confidence < 0.08
      }
      let quality = Self.quality(buffer)
      // Long ink strokes through the middle of a price line may be a
      // crossed-out price. Conservatively hold those for human review.
      let crossed = observations.contains { observation in
        guard observation.topCandidates(1).first?.string.contains("£") == true else { return false }
        return Self.struck(buffer, box: observation.boundingBox)
      }
      let unsafe = ambiguous || alternatives || crossed
      deliver(
        TagEvidence(
          time: time, track: tag, reading: reading, confidence: confidence, sharp: quality,
          ambiguous: unsafe, frameFingerprint: Self.fingerprint(buffer)),
        observations.map(\.boundingBox),
        unsafe
          ? "Unclear or changed price — review manually"
          : (!quality
            ? "Hold still and improve the light"
            : (reading == nil
              ? "Find the description, size and one clear price"
              : "Hold steady — checking the reading")))
    } catch {
      deliver(
        TagEvidence(time: time, track: .zero, confidence: 0, sharp: false, ambiguous: true), [],
        "Reading paused. Keep the tag steady.")
    }
  }
  private static func fingerprint(_ buffer: CVPixelBuffer) -> UInt64 {
    // Replayed/frozen pixel frames do not provide another independent observation.
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return 0 }
    let pixels = base.assumingMemoryBound(to: UInt8.self)
    let width = CVPixelBufferGetWidth(buffer)
    let height = CVPixelBufferGetHeight(buffer)
    let bytes = CVPixelBufferGetBytesPerRow(buffer)
    var hash: UInt64 = 1_469_598_103_934_665_603
    for y in stride(from: height / 4, to: height * 3 / 4, by: 23) {
      for x in stride(from: width / 4, to: width * 3 / 4, by: 19) {
        hash = (hash ^ UInt64(pixels[y * bytes + x * 4 + 1])) &* 1_099_511_628_211
      }
    }
    return hash
  }
  private static func quality(_ buffer: CVPixelBuffer) -> Bool {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return false }
    let p = base.assumingMemoryBound(to: UInt8.self)
    let w = CVPixelBufferGetWidth(buffer)
    let h = CVPixelBufferGetHeight(buffer)
    let stride = CVPixelBufferGetBytesPerRow(buffer)
    var sum = 0
    var edges = 0
    var count = 0
    var clipped = 0
    for y in Swift.stride(from: h / 4, to: 3 * h / 4, by: 4) {
      for x in Swift.stride(from: w / 4, to: 3 * w / 4, by: 4) {
        let a = Int(p[y * stride + x * 4 + 1])
        let b = Int(p[y * stride + (x + 2) * 4 + 1])
        sum += a
        edges += abs(a - b)
        count += 1
        if a > 250 || a < 5 { clipped += 1 }
      }
    }
    return count > 0 && sum / count > 35 && sum / count < 240 && Double(edges) / Double(count) > 3
      && Double(clipped) / Double(count) < 0.65
  }
  private static func struck(_ buffer: CVPixelBuffer, box: CGRect) -> Bool {
    // Vision .right coordinates -> source buffer. Scan horizontal strokes
    // in upright image (vertical runs in the source).
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return true }
    let p = base.assumingMemoryBound(to: UInt8.self)
    let w = CVPixelBufferGetWidth(buffer)
    let h = CVPixelBufferGetHeight(buffer)
    let stride = CVPixelBufferGetBytesPerRow(buffer)
    let y0 = max(0, Int((1 - box.maxX) * Double(h)))
    let y1 = min(h - 1, Int((1 - box.minX) * Double(h)))
    guard y1 - y0 > 12 else { return true }
    for fraction in [0.35, 0.45, 0.55, 0.65] {
      let x = min(w - 1, max(0, Int((1 - box.minY - box.height * fraction) * Double(w))))
      var run = 0
      var longest = 0
      for y in y0...y1 {
        if p[y * stride + x * 4 + 1] < 95 {
          run += 1
          longest = max(longest, run)
        } else {
          run = 0
        }
      }
      if Double(longest) / Double(y1 - y0) > 0.7 { return true }
    }
    return false
  }
}
struct TagCameraPreview: UIViewRepresentable {
  @ObservedObject var scanner: LiveTagScanner
  func makeUIView(context: Context) -> PreviewView {
    let v = PreviewView()
    v.layerView.session = scanner.capture
    v.layerView.videoGravity = .resizeAspectFill
    v.focusAction = { point in scanner.focus(at: point) }
    return v
  }
  func updateUIView(_ view: PreviewView, context: Context) {
    view.boxes = scanner.boxes
    view.setNeedsLayout()
  }
  final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var layerView: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var boxes: [CGRect] = []
    var focusAction: ((CGPoint) -> Void)?
    override init(frame: CGRect) {
      super.init(frame: frame)
      addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focusTap(_:))))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc private func focusTap(_ gesture: UITapGestureRecognizer) {
      focusAction?(
        layerView.captureDevicePointConverted(fromLayerPoint: gesture.location(in: self)))
    }
    private var marks: [CAShapeLayer] = []
    override func layoutSubviews() {
      super.layoutSubviews()
      marks.forEach { $0.removeFromSuperlayer() }
      marks = []
      let grid = CAShapeLayer()
      let path = UIBezierPath()
      for fraction in [CGFloat(1) / 3, CGFloat(2) / 3] {
        path.move(to: CGPoint(x: bounds.width * fraction, y: 0))
        path.addLine(to: CGPoint(x: bounds.width * fraction, y: bounds.height))
        path.move(to: CGPoint(x: 0, y: bounds.height * fraction))
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height * fraction))
      }
      grid.path = path.cgPath
      grid.strokeColor = UIColor.white.withAlphaComponent(0.25).cgColor
      grid.fillColor = UIColor.clear.cgColor
      grid.lineWidth = 1
      layer.addSublayer(grid)
      marks.append(grid)
      for box in boxes {
        let rect = layerView.layerRectConverted(
          fromMetadataOutputRect: CGRect(
            x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height))
        let mark = CAShapeLayer()
        mark.path = UIBezierPath(roundedRect: rect, cornerRadius: 5).cgPath
        mark.fillColor = UIColor.clear.cgColor
        mark.strokeColor = UIColor.systemYellow.cgColor
        mark.lineWidth = 2
        layer.addSublayer(mark)
        marks.append(mark)
      }
    }
  }
}
