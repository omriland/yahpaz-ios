import UIKit
import YahpazDomain

struct CompressedEventImage {
    var bytes: Data
    var width: Int
    var height: Int
}

enum CompressEventImageResult {
    case ok(CompressedEventImage)
    case error(String)
}

func compressEventImage(data: Data, mimeType: String) -> CompressEventImageResult {
    let mime = mimeType.isEmpty ? "image/jpeg" : mimeType
    if let rejected = rejectOriginalFile(mimeType: mime, byteSize: Int64(data.count)) {
        return .error(rejected)
    }
    guard var image = UIImage(data: data) else {
        return .error(EVENT_MEDIA_HEIC_FAIL)
    }
    image = image.normalizedOrientation()
    let size = targetDimensions(
        width: Int(image.size.width.rounded()),
        height: Int(image.size.height.rounded())
    )
    let scaled: UIImage
    if Int(image.size.width.rounded()) == size.0 && Int(image.size.height.rounded()) == size.1 {
        scaled = image
    } else {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size.0, height: size.1), format: format)
        scaled = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: size.0, height: size.1))
        }
    }

    var qualityIndex = 0
    var jpeg: Data?
    while qualityIndex < EVENT_MEDIA_QUALITY_STEPS.count {
        let quality = EVENT_MEDIA_QUALITY_STEPS[qualityIndex]
        guard let bytes = scaled.jpegData(compressionQuality: quality) else {
            return .error(EVENT_MEDIA_COMPRESS_FAIL)
        }
        jpeg = bytes
        if nextJpegQuality(byteSize: bytes.count, qualityIndex: qualityIndex) == nil {
            break
        }
        qualityIndex += 1
    }
    guard let jpeg, jpeg.count <= EVENT_MEDIA_MAX_OUTPUT_BYTES else {
        return .error(EVENT_MEDIA_COMPRESS_FAIL)
    }
    return .ok(CompressedEventImage(bytes: jpeg, width: size.0, height: size.1))
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
