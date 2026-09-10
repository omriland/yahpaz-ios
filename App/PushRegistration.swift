import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushRegistration {
    static let shared = PushRegistration()

    private let tokenKey = "yahpaz.apnsDeviceToken"

    var environment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    func requestAfterSignIn() {
        Task {
            let granted: Bool
            do {
                granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return
            }
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
            if let token = UserDefaults.standard.string(forKey: tokenKey) {
                await upsert(token)
            }
        }
    }

    func didReceiveToken(_ data: Data) {
        let token = data.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
        Task { await upsert(token) }
    }

    func removeCurrentToken() async {
        guard let token = UserDefaults.standard.string(forKey: tokenKey) else { return }
        await YahpazAPI.shared.deleteDeviceToken(token)
    }

    private func upsert(_ token: String) async {
        await YahpazAPI.shared.upsertDeviceToken(token, environment: environment)
    }
}
