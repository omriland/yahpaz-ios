import SwiftUI
import UIKit

struct ForceUpdateView: View {
    let update: ForceUpdateRequired

    var body: some View {
        ZStack {
            CommandTheme.page.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("אבן דרך")
                    .font(TypeScale.brand)
                    .foregroundStyle(CommandTheme.textPrimary)
                if !update.messageHe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(update.messageHe)
                        .font(TypeScale.body)
                        .foregroundStyle(CommandTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                PrimaryButton(title: "עדכון גרסה", command: true) {
                    openAppStore()
                }
            }
            .padding(24)
        }
    }

    /// The app's App Store page from version.json, or the App Store app until that URL is set.
    private func openAppStore() {
        let page = update.appStoreUrl.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        if let url = page ?? URL(string: "itms-apps://apps.apple.com") {
            UIApplication.shared.open(url)
        }
    }
}
