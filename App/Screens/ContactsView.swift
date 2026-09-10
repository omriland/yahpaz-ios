import SwiftUI
import UIKit
import YahpazDomain

struct ContactsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var query = ""

    private var filtered: [UnitContact] {
        filterContacts(app.contacts, query: query) { $0.searchFields }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(CONTACTS_TITLE)
                    .font(TypeScale.title)
                    .foregroundStyle(FieldTheme.textPrimary)
                FormField(
                    label: "חיפוש",
                    placeholder: CONTACTS_SEARCH_PLACEHOLDER,
                    text: $query
                )
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(FieldTheme.page.ignoresSafeArea())
            .yahpazRootNavigationBarHidden()
            .yahpazFormScroll()
            .yahpazKeyboardAccessory()
            .refreshable { await app.reloadContacts() }
            .task(id: app.userId) {
                guard app.userId != nil, app.contacts.isEmpty else { return }
                await app.reloadContacts()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if app.contactsFailed {
            ScrollView {
                EmptyState(
                    title: CONTACTS_FAILED_TITLE,
                    actionTitle: CONTACTS_REFRESH_ACTION
                ) {
                    Task { await app.reloadContacts() }
                }
            }
        } else if app.contactsLoading && app.contacts.isEmpty {
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                ProgressView()
                    .tint(FieldTheme.accent)
                Text(CONTACTS_LOADING_TITLE)
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textSecondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filtered.isEmpty {
            ScrollView {
                EmptyState(
                    title: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? CONTACTS_EMPTY_TITLE
                        : CONTACTS_NO_RESULTS_TITLE,
                    actionTitle: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : CONTACTS_CLEAR_SEARCH_ACTION
                ) {
                    query = ""
                }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filtered) { contact in
                        ContactRow(
                            contact: contact,
                            onCall: { openContactLink(telHref(contact.phone)) },
                            onWhatsApp: { openContactLink(whatsAppHref(contact.phone)) }
                        )
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private func openContactLink(_ href: String?) {
        guard let href, let url = URL(string: href) else {
            app.showToast(CONTACTS_NO_PHONE_TOAST, tone: .pending)
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                Task { @MainActor in
                    app.showToast(CONTACTS_NO_APP_TOAST, tone: .pending)
                }
            }
        }
    }
}

private struct ContactRow: View {
    let contact: UnitContact
    let onCall: () -> Void
    let onWhatsApp: () -> Void

    private var hasPhone: Bool {
        !(contact.phone?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private var canCall: Bool {
        hasPhone && telHref(contact.phone) != nil
    }

    private var canWhatsApp: Bool {
        hasPhone && whatsAppHref(contact.phone) != nil
    }

    private var subtitle: String {
        let parts = [
            contact.callsign.isEmpty ? nil : contact.callsign,
            contact.phone.flatMap { formatted in
                let value = formatPhone(formatted)
                return value.isEmpty ? nil : value
            },
        ].compactMap { $0 }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    var body: some View {
        FieldCard {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.fullName.isEmpty ? CONTACTS_FALLBACK_NAME : contact.fullName)
                        .font(TypeScale.section)
                        .foregroundStyle(FieldTheme.textPrimary)
                    Text(subtitle)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    contactActionButton(
                        enabled: canCall,
                        tinted: hasPhone,
                        label: CONTACTS_CALL_LABEL,
                        action: onCall
                    ) {
                        Image(systemName: "phone")
                            .font(.system(size: 18))
                    }
                    contactActionButton(
                        enabled: canWhatsApp,
                        tinted: hasPhone,
                        label: CONTACTS_WHATSAPP_LABEL,
                        action: onWhatsApp
                    ) {
                        Image("WhatsApp")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    }
                }
            }
            .frame(minHeight: 44)
        }
    }

    private func contactActionButton<Icon: View>(
        enabled: Bool,
        tinted: Bool,
        label: String,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button(action: action) {
            icon()
                .foregroundStyle(tinted ? FieldTheme.accent : FieldTheme.textMuted)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
