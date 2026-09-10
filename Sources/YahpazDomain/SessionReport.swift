import Foundation

/// Same 15-minute window as Android `ANDROID_SESSION_REPORT_THROTTLE_MS`.
public let SESSION_REPORT_THROTTLE_MS: Int64 = 15 * 60 * 1000

/// Existing heartbeat RPC on `profiles` (`last_android_*` columns). No platform argument.
public let SESSION_REPORT_RPC = "report_android_session"

public struct SessionRpcParams: Equatable, Sendable {
    public var versionCode: Int
    public var versionName: String

    public init(versionCode: Int, versionName: String) {
        self.versionCode = versionCode
        self.versionName = versionName
    }
}

public func sessionRpcParams(versionCode: Int, versionName: String) -> SessionRpcParams {
    SessionRpcParams(
        versionCode: versionCode,
        versionName: versionName.trimmingCharacters(in: .whitespacesAndNewlines)
    )
}

public func shouldReportSession(
    lastSuccessAtMs: Int64?,
    nowMs: Int64,
    throttleMs: Int64 = SESSION_REPORT_THROTTLE_MS
) -> Bool {
    guard let lastSuccessAtMs else { return true }
    return nowMs - lastSuccessAtMs >= throttleMs
}
