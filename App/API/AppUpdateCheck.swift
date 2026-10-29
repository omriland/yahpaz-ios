import Foundation
import YahpazDomain

/// `yahpz.com/ios/version.json` (web repo `op-yh-26/public/ios/version.json`). Only `minBuild`
/// gates the app; other keys in that file are ignored.
struct IosVersionManifest: Decodable {
    var minBuild: Int
    var messageHe: String?
    /// App Store page; add it to version.json once the app is live.
    var appStoreUrl: String?
}

struct ForceUpdateRequired: Equatable {
    var messageHe: String
    var appStoreUrl: String?
}

let DEFAULT_FORCE_UPDATE_MESSAGE =
    "יש גרסה חדשה של האפליקציה. יש להוריד ולהתקין כדי להמשיך."

func installedBuildNumber(
    bundle: Bundle = .main
) -> Int {
    let raw = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    return Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
}

func installedVersionName(
    bundle: Bundle = .main
) -> String {
    let raw = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    return raw.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Non-nil when the installed build is below `minBuild`: the app then shows only the update screen.
func checkForceUpdate(currentBuild: Int) async -> ForceUpdateRequired? {
    #if DEBUG
    if StoreScreenshots.isOn { return nil }
    #endif
    guard let manifest = await fetchIosVersionManifest(),
          needsForceUpdate(currentBuild: currentBuild, minBuild: manifest.minBuild)
    else {
        return nil
    }
    let message = manifest.messageHe?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return ForceUpdateRequired(
        messageHe: message.isEmpty ? DEFAULT_FORCE_UPDATE_MESSAGE : message,
        appStoreUrl: manifest.appStoreUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
    )
}

private func fetchIosVersionManifest() async -> IosVersionManifest? {
    var request = URLRequest(url: AppConfig.iosVersionUrl)
    request.httpMethod = "GET"
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.timeoutInterval = 5
    request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
    request.setValue("no-cache", forHTTPHeaderField: "Pragma")
    let config = URLSessionConfiguration.ephemeral
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    config.urlCache = nil
    config.timeoutIntervalForRequest = 5
    config.timeoutIntervalForResource = 5
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }
    do {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }
        return try JSONDecoder().decode(IosVersionManifest.self, from: data)
    } catch {
        return nil
    }
}
