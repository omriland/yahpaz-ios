import Foundation
import YahpazDomain

struct IosVersionManifest: Decodable {
    var minBuild: Int
    var latestBuild: Int?
    var latestVersionName: String?
    var manifestUrl: String?
    var messageHe: String?
}

struct ForceUpdateRequired: Equatable {
    var messageHe: String
    var manifestUrl: String
}

struct OptionalUpdateAvailable: Equatable {
    var messageHe: String
    var manifestUrl: String
    var latestBuild: Int
    var latestVersionName: String
}

struct SideloadUpdateCheck: Equatable {
    var force: ForceUpdateRequired? = nil
    var optional: OptionalUpdateAvailable? = nil
}

let DEFAULT_FORCE_UPDATE_MESSAGE =
    "יש גרסה חדשה של האפליקציה. יש להוריד ולהתקין כדי להמשיך."

let DEFAULT_OPTIONAL_UPDATE_MESSAGE =
    "יש עדכון לאבן דרך. אפשר להתקין עכשיו בלי לפתוח את החנות."

enum OptionalUpdatePrefs {
    private static let skippedKey = "yahpaz_app_update.skipped_latest_version_code"

    static var skippedLatestBuild: Int {
        UserDefaults.standard.integer(forKey: skippedKey)
    }

    static func skip(latestBuild: Int) {
        UserDefaults.standard.set(latestBuild, forKey: skippedKey)
    }
}

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

func checkSideloadUpdates(currentBuild: Int) async -> SideloadUpdateCheck {
    guard let manifest = await fetchIosVersionManifest() else {
        return SideloadUpdateCheck()
    }
    let manifestUrl = {
        let raw = manifest.manifestUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? AppConfig.defaultIosManifestUrl : raw
    }()
    if needsForceUpdate(currentBuild: currentBuild, minBuild: manifest.minBuild) {
        let message = manifest.messageHe?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return SideloadUpdateCheck(
            force: ForceUpdateRequired(
                messageHe: message.isEmpty ? DEFAULT_FORCE_UPDATE_MESSAGE : message,
                manifestUrl: manifestUrl
            )
        )
    }
    let latestBuild = manifest.latestBuild ?? manifest.minBuild
    if needsOptionalUpdate(currentBuild: currentBuild, minBuild: manifest.minBuild, latestBuild: latestBuild) {
        let named = manifest.latestVersionName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let message = named.isEmpty
            ? DEFAULT_OPTIONAL_UPDATE_MESSAGE
            : "יש עדכון לאבן דרך (\(named)). אפשר להתקין עכשיו בלי לפתוח את החנות."
        return SideloadUpdateCheck(
            optional: OptionalUpdateAvailable(
                messageHe: message,
                manifestUrl: manifestUrl,
                latestBuild: latestBuild,
                latestVersionName: named
            )
        )
    }
    return SideloadUpdateCheck()
}

func installActionURL(manifestUrl: String) -> URL {
    if let href = itmsInstallHref(manifestUrl), let url = URL(string: href) {
        return url
    }
    return AppConfig.iosInstallPageUrl
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
