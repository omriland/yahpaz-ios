import Foundation

public let EVENT_MEDIA_MAX_ORIGINAL_BYTES: Int64 = 20 * 1024 * 1024
public let EVENT_MEDIA_MAX_OUTPUT_BYTES = Int(1.5 * 1024 * 1024)
public let EVENT_MEDIA_MAX_LONG_EDGE = 1600
public let EVENT_MEDIA_TARGET_BYTES = 700 * 1024
public let EVENT_MEDIA_QUALITY_STEPS: [Double] = [0.72, 0.6, 0.5]

public func rejectOriginalFile(mimeType: String, byteSize: Int64) -> String? {
    if byteSize <= 0 { return EVENT_MEDIA_BAD_TYPE }
    if !mimeType.hasPrefix("image/") { return EVENT_MEDIA_BAD_TYPE }
    if byteSize > EVENT_MEDIA_MAX_ORIGINAL_BYTES { return EVENT_MEDIA_TOO_LARGE }
    return nil
}

public func targetDimensions(
    width: Int,
    height: Int,
    maxLongEdge: Int = EVENT_MEDIA_MAX_LONG_EDGE
) -> (Int, Int) {
    let longEdge = max(width, height)
    if longEdge <= maxLongEdge { return (width, height) }
    let scale = Double(maxLongEdge) / Double(longEdge)
    return (
        max(1, Int((Double(width) * scale).rounded())),
        max(1, Int((Double(height) * scale).rounded()))
    )
}

public func nextJpegQuality(byteSize: Int, qualityIndex: Int) -> Double? {
    if byteSize <= EVENT_MEDIA_TARGET_BYTES { return nil }
    let nextIndex = qualityIndex + 1
    if nextIndex >= EVENT_MEDIA_QUALITY_STEPS.count { return nil }
    return EVENT_MEDIA_QUALITY_STEPS[nextIndex]
}

public func jpegQualityPercent(_ quality: Double) -> Int {
    min(100, max(1, Int(quality * 100.0)))
}
