import ImageIO
import UIKit
import UniformTypeIdentifiers

struct WPreparedPhoto: Sendable {
  var original: Data, web: Data, width: Int, height: Int, contentType: String, extensionName: String
}
enum WPhotoPreparation {
  static func thumbnail(_ data: Data) -> UIImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: 600, kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    else { return nil }
    return UIImage(cgImage: image)
  }
  static func prepare(_ data: Data) throws -> WPreparedPhoto {
    guard data.count <= 20 * 1024 * 1024,
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      let type = CGImageSourceGetType(source)
    else { throw WError.message("Choose a photograph under 20 MB") }
    let identifier = type as String
    let contentType: String
    let extensionName: String
    switch identifier {
    case UTType.jpeg.identifier:
      contentType = "image/jpeg"
      extensionName = "jpg"
    case UTType.png.identifier:
      contentType = "image/png"
      extensionName = "png"
    case UTType.heic.identifier, UTType.heif.identifier:
      contentType = "image/heic"
      extensionName = "heic"
    default: throw WError.message("Use a JPEG, PNG or HEIC photograph")
    }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1600,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
      let web = UIImage(cgImage: thumb).jpegData(compressionQuality: 0.86)
    else { throw WError.message("Could not prepare the photograph") }
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    return WPreparedPhoto(
      original: data, web: web,
      width: properties?[kCGImagePropertyPixelWidth] as? Int ?? thumb.width,
      height: properties?[kCGImagePropertyPixelHeight] as? Int ?? thumb.height,
      contentType: contentType, extensionName: extensionName)
  }
}
