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
                InAppUpdateActions(
                    manifestUrl: update.manifestUrl,
                    updateTitle: "הורדה והתקנה",
                    command: true
                )
            }
            .padding(24)
        }
    }
}

struct OptionalUpdateSheet: View {
    let update: OptionalUpdateAvailable
    var onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("גרסה חדשה")
                .font(TypeScale.title)
                .foregroundStyle(FieldTheme.textPrimary)
            Text(update.messageHe.isEmpty ? DEFAULT_OPTIONAL_UPDATE_MESSAGE : update.messageHe)
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.textSecondary)
            InAppUpdateActions(
                manifestUrl: update.manifestUrl,
                updateTitle: "עדכון",
                laterTitle: "אחר כך",
                onLater: onLater
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
        .padding(.top, 8)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he"))
        .yahpazFormScroll()
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium])
    }
}

private struct InAppUpdateActions: View {
    let manifestUrl: String
    let updateTitle: String
    var laterTitle: String? = nil
    var onLater: (() -> Void)? = nil
    var command = false

    @State private var busy = false
    @State private var errorHe: String?

    var body: some View {
        VStack(spacing: 12) {
            if let errorHe {
                Text(errorHe)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            PrimaryButton(title: updateTitle, busy: busy, enabled: !busy, command: command) {
                openInstall()
            }
            if let laterTitle, let onLater {
                GhostButton(title: laterTitle, enabled: !busy, action: onLater)
            }
        }
    }

    private func openInstall() {
        errorHe = nil
        busy = true
        let primary = installActionURL(manifestUrl: manifestUrl)
        UIApplication.shared.open(primary, options: [:]) { success in
            if success {
                Task { @MainActor in busy = false }
                return
            }
            if primary != AppConfig.iosInstallPageUrl {
                UIApplication.shared.open(AppConfig.iosInstallPageUrl, options: [:]) { fallback in
                    Task { @MainActor in
                        busy = false
                        if !fallback {
                            errorHe = "ההורדה נכשלה. נסו שוב."
                        }
                    }
                }
                return
            }
            Task { @MainActor in
                busy = false
                errorHe = "ההורדה נכשלה. נסו שוב."
            }
        }
    }
}
