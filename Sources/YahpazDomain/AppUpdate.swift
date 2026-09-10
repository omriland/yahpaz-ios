import Foundation

/// True when the installed build is below the server minimum (hard force update).
public func needsForceUpdate(currentBuild: Int, minBuild: Int) -> Bool {
    currentBuild < minBuild
}

/// True when the build may keep running but a newer package is available.
public func needsOptionalUpdate(currentBuild: Int, minBuild: Int, latestBuild: Int) -> Bool {
    currentBuild >= minBuild && currentBuild < latestBuild
}

/// OTA install URL for an https yahpz.com `.plist` — same encoding as the web `/ios` page.
public func itmsInstallHref(_ manifestUrl: String) -> String? {
    let raw = manifestUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty, let url = URL(string: raw) else { return nil }
    guard url.scheme?.lowercased() == "https" else { return nil }
    let host = url.host?.lowercased() ?? ""
    guard host == "yahpz.com" || host == "www.yahpz.com" else { return nil }
    guard url.path.lowercased().hasSuffix(".plist") else { return nil }
    guard let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: uriComponentAllowed) else {
        return nil
    }
    return "itms-services://?action=download-manifest&url=\(encoded)"
}

/// `encodeURIComponent` allowed set — must match `op-yh-26/src/lib/iosDownload.ts`.
private let uriComponentAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")
