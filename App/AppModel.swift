import Foundation
import SwiftUI
import YahpazDomain

@MainActor
final class AppModel: ObservableObject {
    enum Tab: Hashable {
        case inbox
        case availability
        case profile
    }

    @Published var booting = true
    @Published var userId: String?
    @Published var profile: ProfileRecord?
    @Published var roles: [String] = []
    @Published var events: [EventListItem] = []
    @Published var eventsFailed = false
    @Published var eventsLoading = false
    @Published var tab: Tab = .inbox
    @Published var toast: String?
    @Published var toastTone: StampTone = .done
    @Published var trackToken: String?
    @Published var mustChangePassword = false

    private var toastTask: Task<Void, Never>?

    var isSignedIn: Bool { userId != nil && profile != nil }

    func bootstrap() async {
        booting = true
        if let id = await YahpazAPI.shared.sessionUserId() {
            try? await applySession(userId: id)
        } else {
            userId = nil
            profile = nil
        }
        booting = false
    }

    func applyIncomingURL(_ url: URL) {
        if let token = parseTrackToken(from: url.absoluteString) {
            trackToken = token
        }
    }

    func signIn(email: String, password: String) async -> String? {
        if let error = await YahpazAPI.shared.signIn(email: email, password: password) {
            return error
        }
        if let id = await YahpazAPI.shared.sessionUserId() {
            do {
                try await applySession(userId: id)
                return nil
            } catch {
                return error.localizedDescription
            }
        }
        return "הכניסה נכשלה. בדקו את החיבור ונסו שוב."
    }

    func signOut() async {
        await YahpazAPI.shared.signOut()
        userId = nil
        profile = nil
        roles = []
        events = []
        mustChangePassword = false
        tab = .inbox
    }

    func reloadEvents() async {
        guard userId != nil else { return }
        eventsLoading = true
        eventsFailed = false
        do {
            events = try await YahpazAPI.shared.fetchMyEvents()
        } catch {
            eventsFailed = true
        }
        eventsLoading = false
    }

    func showToast(_ text: String, tone: StampTone = .done) {
        toast = text
        toastTone = tone
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if !Task.isCancelled { toast = nil }
        }
    }

    func saveAvailability(status: AvailabilityStatus, availableFrom: String?) async -> String? {
        guard let userId else { return "יש להתחבר מחדש." }
        if let error = await YahpazAPI.shared.saveAvailability(
            userId: userId,
            status: status,
            availableFrom: availableFrom
        ) {
            return error
        }
        if var current = profile {
            current.availability = status
            current.availableFrom = status == .available ? nil : availableFrom
            profile = current
        }
        showToast("הזמינות עודכנה.", tone: .done)
        return nil
    }

    func completePasswordChange(_ password: String) async -> String? {
        if let error = await YahpazAPI.shared.updatePassword(password) {
            return error
        }
        mustChangePassword = false
        if var current = profile {
            current.mustChangePassword = false
            profile = current
        }
        showToast("הסיסמה עודכנה.", tone: .done)
        return nil
    }

    private func applySession(userId: String) async throws {
        do {
            let (profile, roles) = try await YahpazAPI.shared.loadProfile()
            self.userId = userId
            self.profile = profile
            self.roles = roles
            self.mustChangePassword = profile.mustChangePassword
            await reloadEvents()
        } catch {
            self.userId = nil
            self.profile = nil
            throw error
        }
    }
}
