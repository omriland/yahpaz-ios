import SwiftUI
import YahpazDomain

struct LoginView: View {
    @EnvironmentObject private var app: AppModel
    @State private var email = ""
    @State private var password = ""
    @State private var mode = Mode.signin
    @State private var error: String?
    @State private var busy = false

    enum Mode { case signin, reset, resetSent }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    masthead
                    card
                    PrivacyPolicyLink(command: true, onOpen: { app.openPrivacy() })
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .yahpazFormScroll()
            .yahpazKeyboardAccessory()
            .scrollContentBackground(.hidden)
            .background(CommandTheme.page.ignoresSafeArea())
            .yahpazRootNavigationBarHidden()
        }
    }

    private var masthead: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("אבן דרך")
                .font(TypeScale.brand)
                .foregroundStyle(CommandTheme.textPrimary)
            Rectangle()
                .fill(CommandTheme.hairline)
                .frame(width: 1, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text("היחידה הארצית")
                    .font(TypeScale.label)
                    .foregroundStyle(CommandTheme.textSecondary)
                Text("לפינוי צירים")
                    .font(TypeScale.label)
                    .foregroundStyle(CommandTheme.textSecondary)
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(mode == .signin ? "כניסה למערכת" : "איפוס סיסמה")
                .font(TypeScale.section)
                .foregroundStyle(FieldTheme.textPrimary)
            if let error {
                Text(error)
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.alert)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FieldTheme.alertTint)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            if mode == .resetSent {
                Text("אם קיים חשבון לכתובת זו, נשלח קישור לאיפוס הסיסמה.")
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textSecondary)
                GhostButton(title: "חזרה לכניסה") {
                    mode = .signin
                    error = nil
                }
            } else {
                FormField(
                    label: "דוא״ל",
                    keyboard: .emailAddress,
                    ltr: true,
                    submit: mode == .signin ? .next : .go,
                    contentType: .username,
                    onSubmit: { if mode != .signin { Task { await submit() } } },
                    text: $email
                )
                if mode == .signin {
                    SecureFormField(
                        label: "סיסמה",
                        contentType: .password,
                        submit: .go,
                        onSubmit: { Task { await submit() } },
                        text: $password
                    )
                }
                PrimaryButton(
                    title: mode == .signin ? "כניסה" : "שליחת קישור",
                    busy: busy,
                    enabled: !email.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    Task { await submit() }
                }
                Button(mode == .signin ? "שכחתי סיסמה" : "חזרה לכניסה") {
                    error = nil
                    mode = mode == .signin ? .reset : .signin
                }
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.accent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(FieldTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color(hex: 0x0F1B2D).opacity(0.16), radius: 12, y: 8)
        .frame(maxWidth: 460)
    }

    private func submit() async {
        busy = true
        error = nil
        let trimmed = normalizeLoginEmail(email)
        if mode == .signin {
            error = await app.signIn(email: trimmed, password: normalizeLoginSecret(password))
        } else {
            if let message = await YahpazAPI.shared.requestPasswordReset(email: trimmed) {
                error = message
            } else {
                mode = .resetSent
            }
        }
        busy = false
    }
}
