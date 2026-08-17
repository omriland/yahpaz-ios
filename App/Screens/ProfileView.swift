import SwiftUI
import YahpazDomain

struct ProfileView: View {
    @EnvironmentObject private var app: AppModel
    @State private var password = ""
    @State private var confirm = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("פרופיל")
                        .font(TypeScale.title)
                        .foregroundStyle(FieldTheme.textPrimary)
                    if let profile = app.profile {
                        VStack(alignment: .leading, spacing: 0) {
                            LedgerRow(label: "שם", value: profile.fullName)
                            LedgerRow(label: "או״ק", value: profile.callsign)
                            LedgerRow(label: "דוא״ל", value: profile.email)
                            LedgerRow(label: "טלפון", value: profile.phone ?? "")
                        }
                        .padding(16)
                        .background(FieldTheme.raised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(FieldTheme.hairline, lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("סיכום פעילות")
                                .font(TypeScale.section)
                                .foregroundStyle(FieldTheme.textPrimary)
                            LedgerRow(label: "אירועים", value: String(profile.lifetimeEventCount))
                            LedgerRow(label: "קילומטרים", value: String(Int(profile.lifetimeKm)))
                        }
                        .padding(16)
                        .background(FieldTheme.raised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(FieldTheme.hairline, lineWidth: 1)
                        )
                    }

                    if app.mustChangePassword {
                        passwordGate
                    }

                    GhostButton(title: "יציאה") {
                        Task { await app.signOut() }
                    }
                }
                .padding(16)
            }
            .background(FieldTheme.page.ignoresSafeArea())
        }
    }

    private var passwordGate: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("יש לבחור סיסמה חדשה")
                .font(TypeScale.section)
                .foregroundStyle(FieldTheme.textPrimary)
            SecureField("סיסמה חדשה", text: $password)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(FieldTheme.strong, lineWidth: 1)
                )
            SecureField("אימות סיסמה", text: $confirm)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(FieldTheme.strong, lineWidth: 1)
                )
            if let error {
                Text(error)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
            }
            PrimaryButton(title: "שמירת סיסמה", busy: busy) {
                Task { await savePassword() }
            }
        }
        .padding(16)
        .background(FieldTheme.raised)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FieldTheme.hairline, lineWidth: 1)
        )
    }

    private func savePassword() async {
        if password != confirm {
            error = "הסיסמאות אינן זהות."
            return
        }
        busy = true
        error = await app.completePasswordChange(password)
        busy = false
    }
}
