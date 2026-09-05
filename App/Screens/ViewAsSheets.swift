import SwiftUI
import YahpazDomain

struct ViewAsBanner: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        if app.impersonating, let name = app.impersonationName {
            ViewAsBannerCard(
                text: impersonationBannerText(fullName: name, callsign: app.impersonationCallsign ?? ""),
                action: STOP_IMPERSONATION_LABEL
            ) {
                Task { await app.stopImpersonation() }
            }
        } else if let preview = parseRolePreviewRole(app.previewRole) {
            ViewAsBannerCard(
                text: rolePreviewBannerText(preview),
                action: STOP_ROLE_PREVIEW_LABEL
            ) {
                Task { await app.stopRolePreview() }
            }
        }
    }
}

private struct ViewAsBannerCard: View {
    let text: String
    let action: String
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(TypeScale.caption)
                .foregroundStyle(FieldTheme.textPrimary)
            GhostButton(title: action, action: onAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldTheme.accentSubtle)
    }
}

struct RolePreviewSheet: View {
    let onClose: () -> Void
    let onPick: (AppRole) -> Void

    @State private var selected: AppRole = .responder

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(VIEW_AS_ROLE_LABEL)
                .font(TypeScale.title)
                .foregroundStyle(FieldTheme.textPrimary)
            Text(ROLE_PREVIEW_HINT)
                .font(TypeScale.caption)
                .foregroundStyle(FieldTheme.textMuted)
            ForEach(PREVIEWABLE_ROLES, id: \.rawValue) { role in
                ChoiceRow(
                    title: rolePreviewLabel(role),
                    selected: selected == role
                ) {
                    selected = role
                }
            }
            PrimaryButton(title: "המשך כ־\(rolePreviewLabel(selected))") {
                onPick(selected)
            }
            GhostButton(title: "ביטול", action: onClose)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .background(FieldTheme.page.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct ImpersonationSheet: View {
    let actorUserId: String
    let onClose: () -> Void
    let onConfirm: (String) async -> String?

    @State private var query = ""
    @State private var candidates: [AdminUserListItem]?
    @State private var loadError: String?
    @State private var selectedId: String?
    @State private var busy = false
    @State private var actionError: String?

    private var filtered: [AdminUserListItem] {
        let rows = candidates ?? []
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return rows }
        return rows.filter { fieldsMatchQuery([$0.fullName, $0.callsign, $0.email], query: trimmed) }
    }

    private var selected: AdminUserListItem? {
        filtered.first { $0.id == selectedId }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(VIEW_AS_USER_LABEL)
                    .font(TypeScale.title)
                    .foregroundStyle(FieldTheme.textPrimary)
                Text(IMPERSONATION_HINT)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                FormField(
                    label: "חיפוש",
                    placeholder: USERS_SEARCH_PLACEHOLDER,
                    text: $query
                )
                if let loadError {
                    Text(loadError)
                        .font(TypeScale.body)
                        .foregroundStyle(FieldTheme.alert)
                }
                if let actionError {
                    Text(actionError)
                        .font(TypeScale.body)
                        .foregroundStyle(FieldTheme.alert)
                }
                if candidates == nil && loadError == nil {
                    Text("טוען…")
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                }
                if candidates != nil && filtered.isEmpty {
                    Text(IMPERSONATION_EMPTY)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                }
                ForEach(filtered) { row in
                    ChoiceRow(
                        title: row.fullName,
                        caption: "או״ק \(row.callsign) · \(row.email)",
                        selected: row.id == selectedId
                    ) {
                        selectedId = row.id
                    }
                }
                PrimaryButton(
                    title: selected.map { "המשך כ־\($0.fullName)" } ?? "המשך",
                    busy: busy,
                    enabled: selected != nil && !busy
                ) {
                    guard let id = selected?.id else { return }
                    Task {
                        busy = true
                        actionError = nil
                        let error = await onConfirm(id)
                        busy = false
                        if let error {
                            actionError = error
                        } else {
                            onClose()
                        }
                    }
                }
                GhostButton(title: "ביטול", enabled: !busy, action: onClose)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .frame(maxHeight: 640)
        .yahpazFormScroll()
        .yahpazKeyboardAccessory()
        .background(FieldTheme.page.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(busy)
        .task(id: actorUserId) {
            loadError = nil
            candidates = nil
            do {
                candidates = try await YahpazAPI.shared.fetchImpersonationCandidates(actorUserId: actorUserId)
            } catch {
                loadError = IMPERSONATION_LOAD_FAILED
            }
        }
    }
}

struct MoreViewAsRows: View {
    let canViewAsUser: Bool
    let canViewAsRole: Bool
    let impersonating: Bool
    let previewing: Bool
    let onViewAsUser: () -> Void
    let onViewAsRole: () -> Void
    let onStopImpersonation: () -> Void
    let onStopPreview: () -> Void

    var body: some View {
        Group {
            if canViewAsUser {
                MoreActionRow(label: VIEW_AS_USER_LABEL, action: onViewAsUser)
            }
            if canViewAsRole {
                MoreActionRow(label: VIEW_AS_ROLE_LABEL, action: onViewAsRole)
            }
            if previewing {
                MoreActionRow(label: STOP_ROLE_PREVIEW_LABEL, action: onStopPreview)
            }
            if impersonating {
                MoreActionRow(label: STOP_IMPERSONATION_LABEL, action: onStopImpersonation)
            }
        }
    }
}

private struct MoreActionRow: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct ChoiceRow: View {
    let title: String
    var caption: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(selected ? TypeScale.bodyStrong : TypeScale.body)
                    .foregroundStyle(selected ? FieldTheme.accent : FieldTheme.textPrimary)
                if let caption {
                    Text(caption)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(selected ? FieldTheme.accentSubtle : FieldTheme.raised)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(selected ? FieldTheme.accent : FieldTheme.strong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
