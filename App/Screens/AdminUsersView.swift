import SwiftUI
import UIKit
import YahpazDomain

private enum AdminConfirm: Identifiable {
    case deactivate(AdminUserListItem)
    case delete(AdminUserListItem)
    case otp(AdminUserListItem, kind: String)
    case vehicle(mode: String, vehicle: AdminVehicleDraft)

    var id: String {
        switch self {
        case .deactivate(let user): return "deactivate-\(user.id)"
        case .delete(let user): return "delete-\(user.id)"
        case .otp(let user, let kind): return "otp-\(kind)-\(user.id)"
        case .vehicle(let mode, let vehicle): return "vehicle-\(mode)-\(vehicle.key)"
        }
    }
}

struct AdminUsersView: View {
    @EnvironmentObject private var app: AppModel
    @State private var query = ""
    @State private var detail: AdminUserListItem?
    @State private var form: InviteDraft?
    @State private var confirm: AdminConfirm?
    @State private var saving = false
    @State private var formError: String?

    private var today: String { israelToday() }
    private var actorIsSuperAdmin: Bool { hasSuperAdminRole(app.roles) }

    private var filtered: [AdminUserListItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return app.adminUsers }
        return app.adminUsers.filter { adminUserMatchesQuery($0.searchInput, query: trimmed, today: today) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(USERS_TITLE)
                .font(TypeScale.title)
                .foregroundStyle(FieldTheme.textPrimary)
            FormField(
                label: "חיפוש",
                placeholder: USERS_SEARCH_PLACEHOLDER,
                text: $query
            )
            GhostButton(title: INVITE_TITLE) {
                formError = nil
                form = InviteDraft()
            }
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FieldTheme.page.ignoresSafeArea())
        .yahpazFormScroll()
        .yahpazKeyboardAccessory()
        .refreshable { await app.reloadAdminUsers() }
        .task(id: app.userId) {
            guard app.userId != nil, app.adminUsers.isEmpty else { return }
            await app.reloadAdminUsers()
        }
        .fullScreenCover(isPresented: Binding(
            get: { form != nil },
            set: { if !$0, !saving { form = nil } }
        )) {
            if let draft = form {
                AdminUserFormView(
                    draft: draft,
                    actorUserId: app.userId,
                    addresses: app.adminUsers.first(where: { $0.id == draft.id })?.addresses ?? [],
                    saving: saving,
                    formError: formError,
                    onChange: { form = $0 },
                    onClose: { if !saving { form = nil } },
                    onSave: { saveForm() },
                    onRemoveVehicle: { removeVehicle($0) },
                    onUnarchiveVehicle: { unarchiveVehicle($0) }
                )
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he"))
                .sheet(item: $confirm) { opened in
                    confirmSheet(opened)
                        .environment(\.layoutDirection, .rightToLeft)
                        .environment(\.locale, Locale(identifier: "he"))
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
        }
        .sheet(item: $detail) { opened in
            let user = app.adminUsers.first(where: { $0.id == opened.id }) ?? opened
            AdminUserDetailSheet(
                user: user,
                today: today,
                actorUserId: app.userId,
                actorIsSuperAdmin: actorIsSuperAdmin,
                onEdit: {
                    formError = nil
                    form = draftFromUser(user)
                    detail = nil
                },
                onOtpLogin: { handleOtp(user, kind: "login") },
                onOtpUsersPage: { handleOtp(user, kind: "users_page") },
                onResendInvite: { Task { await resendInvite(user) } },
                onCopyInvite: { Task { await copyInvite(user) } },
                onSetActive: {
                    if user.active {
                        confirm = .deactivate(user)
                    } else {
                        Task {
                            if let error = await app.setUserActive(userId: user.id, active: true) {
                                app.showToast(error, tone: .pending)
                            }
                        }
                    }
                },
                onDelete: { confirm = .delete(user) },
                onClose: { detail = nil }
            )
            .environmentObject(app)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "he"))
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .sheet(item: $confirm) { opened in
                confirmSheet(opened)
                    .environment(\.layoutDirection, .rightToLeft)
                    .environment(\.locale, Locale(identifier: "he"))
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if app.adminUsersFailed {
            ScrollView {
                EmptyState(
                    title: "טעינת המשתמשים נכשלה. בדקו את החיבור ונסו שוב.",
                    actionTitle: "רענון"
                ) {
                    Task { await app.reloadAdminUsers() }
                }
            }
        } else if app.adminUsersLoading && app.adminUsers.isEmpty {
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                ProgressView()
                    .tint(FieldTheme.accent)
                Text("טוען משתמשים…")
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textSecondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filtered.isEmpty {
            ScrollView {
                EmptyState(
                    title: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "אין משתמשים להצגה"
                        : "לא נמצאו משתמשים תואמים",
                    caption: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "משתמש חדש יופיע כאן ברגע שיוזמן."
                        : nil,
                    actionTitle: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? INVITE_TITLE
                        : "ניקוי חיפוש"
                ) {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        formError = nil
                        form = InviteDraft()
                    } else {
                        query = ""
                    }
                }
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    Text(adminUsersCountLabel(filtered.count))
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                    ForEach(filtered) { user in
                        Button { detail = user } label: {
                            AdminUserRow(user: user, today: today)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 24)
                }
            }
        }
    }

    private func saveForm() {
        guard let draft = form else { return }
        let next = validateAdminUserDraft(
            draft,
            actorUserId: app.userId,
            isSuperAdmin: actorIsSuperAdmin,
            existingRoles: app.adminUsers.first(where: { $0.id == draft.id })?.roles ?? draft.roles
        )
        if !next.isEmpty {
            formError = next.formMessage
            return
        }
        formError = nil
        Task {
            saving = true
            if draft.id == nil {
                let result = await app.inviteUser(draft)
                saving = false
                if let error = result.error {
                    formError = error
                } else {
                    let copied = copyInviteLink(result.actionLink)
                    app.showToast(
                        copied ? USER_CREATED_COPIED : (result.message ?? USER_CREATED),
                        tone: .done
                    )
                    form = nil
                }
            } else {
                formError = await app.saveAdminUser(draft)
                saving = false
                if formError == nil { form = nil }
            }
        }
    }

    private func removeVehicle(_ vehicle: AdminVehicleDraft) {
        if vehicle.archived { return }
        guard let vehicleId = vehicle.id, !vehicleId.isEmpty, let userId = form?.id else {
            confirm = .vehicle(mode: "delete", vehicle: vehicle)
            return
        }
        Task {
            let attached = await app.isVehicleAttachedToEvents(
                userId: userId,
                vehicleId: vehicleId,
                plateNumber: vehicle.plateNumber
            )
            confirm = .vehicle(mode: attached ? "archive" : "delete", vehicle: vehicle)
        }
    }

    private func unarchiveVehicle(_ vehicle: AdminVehicleDraft) {
        guard let id = vehicle.id, var draft = form else { return }
        Task {
            if let error = await app.unarchiveAdminVehicle(vehicleId: id) {
                formError = error
                return
            }
            draft.vehicles = draft.vehicles.map {
                $0.key == vehicle.key ? AdminVehicleDraft(
                    key: $0.key,
                    id: $0.id,
                    plateNumber: $0.plateNumber,
                    model: $0.model,
                    archived: false
                ) : $0
            }
            form = draft
            await app.reloadAdminUsers()
        }
    }

    private func handleOtp(_ user: AdminUserListItem, kind: String) {
        let enabled = kind == "users_page" ? user.otpUsersPageEnabled : user.otpLoginEnabled
        if enabled {
            Task {
                if let error = await app.setAdminUserOtp(userId: user.id, kind: kind, enabled: false) {
                    app.showToast(error, tone: .pending)
                }
            }
        } else if !isValidIlMobile(user.phone) {
            app.showToast(OTP_PHONE_REQUIRED, tone: .pending)
        } else {
            confirm = .otp(user, kind: kind)
        }
    }

    private func resendInvite(_ user: AdminUserListItem) async {
        let result = await app.resendAdminInvite(user.id)
        if let error = result.error {
            app.showToast(error, tone: .pending)
            return
        }
        let copied = copyInviteLink(result.actionLink)
        app.showToast(
            copied ? INVITE_RESENT_COPIED : (result.message ?? OVERFLOW_RESEND_INVITE),
            tone: .done
        )
    }

    private func copyInvite(_ user: AdminUserListItem) async {
        let result = await app.copyAdminInviteLink(user.id)
        if let error = result.error {
            app.showToast(error, tone: .pending)
            return
        }
        let copied = copyInviteLink(result.actionLink)
        app.showToast(
            copied ? INVITE_LINK_COPIED : INVITE_LINK_COPY_FAILED,
            tone: copied ? .done : .pending
        )
    }

    @ViewBuilder
    private func confirmSheet(_ opened: AdminConfirm) -> some View {
        switch opened {
        case .deactivate(let user):
            AdminConfirmSheet(
                title: deactivateConfirmTitle(user.fullName),
                message: DEACTIVATE_USER_BODY,
                action: DEACTIVATE_USER_ACTION,
                danger: true,
                saving: saving,
                onCancel: { confirm = nil },
                onConfirm: {
                    Task {
                        saving = true
                        let error = await app.setUserActive(userId: user.id, active: false)
                        saving = false
                        confirm = nil
                        if let error { app.showToast(error, tone: .pending) }
                    }
                }
            )
        case .delete(let user):
            AdminConfirmSheet(
                title: deleteUserConfirm(user.fullName),
                message: DELETE_USER_BODY,
                action: DELETE_USER_ACTION,
                danger: true,
                saving: saving,
                onCancel: { confirm = nil },
                onConfirm: {
                    if user.id == app.userId {
                        app.showToast(SELF_DELETE_ERROR, tone: .pending)
                        confirm = nil
                        return
                    }
                    Task {
                        saving = true
                        let error = await app.deleteAdminUser(user.id)
                        saving = false
                        confirm = nil
                        detail = nil
                        if form?.id == user.id { form = nil }
                        if let error { app.showToast(error, tone: .pending) }
                    }
                }
            )
        case .otp(let user, let kind):
            AdminConfirmSheet(
                title: kind == "users_page" ? OTP_ENABLE_USERS_PAGE_TITLE : OTP_ENABLE_LOGIN_TITLE,
                message: otpEnableConfirmBody(phone: user.phone),
                action: OTP_ENABLE_ACTION,
                danger: false,
                saving: saving,
                onCancel: { confirm = nil },
                onConfirm: {
                    Task {
                        saving = true
                        let error = await app.setAdminUserOtp(userId: user.id, kind: kind, enabled: true)
                        saving = false
                        confirm = nil
                        if let error { app.showToast(error, tone: .pending) }
                    }
                }
            )
        case .vehicle(let mode, let vehicle):
            AdminConfirmSheet(
                title: mode == "archive" ? "העברה לארכיון" : "מחיקת רכב",
                message: mode == "archive" ? VEHICLE_ARCHIVE_CONFIRM : VEHICLE_DELETE_CONFIRM,
                action: mode == "archive" ? "העברה לארכיון" : "מחיקה",
                danger: mode != "archive",
                saving: saving,
                onCancel: { confirm = nil },
                onConfirm: {
                    guard var current = form else { return }
                    let vehicleId = vehicle.id
                    if vehicleId == nil || vehicleId?.isEmpty == true || current.id == nil {
                        current.vehicles = current.vehicles.filter { $0.key != vehicle.key }
                        form = current
                        confirm = nil
                        return
                    }
                    Task {
                        saving = true
                        let error: String?
                        if mode == "archive" {
                            error = await app.archiveAdminVehicle(vehicleId: vehicleId!)
                        } else {
                            error = await app.deleteAdminVehicle(vehicleId: vehicleId!)
                        }
                        saving = false
                        if let error {
                            formError = error
                            return
                        }
                        if mode == "archive" {
                            current.vehicles = current.vehicles.map {
                                $0.key == vehicle.key
                                    ? AdminVehicleDraft(
                                        key: $0.key,
                                        id: $0.id,
                                        plateNumber: $0.plateNumber,
                                        model: $0.model,
                                        archived: true
                                    )
                                    : $0
                            }
                        } else {
                            current.vehicles = current.vehicles.filter { $0.key != vehicle.key }
                        }
                        form = current
                        await app.reloadAdminUsers()
                        confirm = nil
                    }
                }
            )
        }
    }
}

private struct AdminUserRow: View {
    let user: AdminUserListItem
    let today: String

    var body: some View {
        let invitePending = isInvitePending(active: user.active, invitePending: user.invitePending)
        let effective = effectiveAvailability(user.availability, availableFrom: user.availableFrom, today: today)
        FieldCard {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName.isEmpty ? "משתמש" : user.fullName)
                        .font(TypeScale.section)
                        .foregroundStyle(FieldTheme.textPrimary)
                    Text(
                        [user.callsign, roleLabels(user.roles).first ?? ""]
                            .filter { !$0.isEmpty }
                            .joined(separator: " · ")
                    )
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                }
                Spacer(minLength: 8)
                if hasAvailability(active: user.active, invitePending: user.invitePending) {
                    StampChip(
                        stamp: StampDescriptor(
                            label: availabilityLabel(effective),
                            tone: effective == .available ? .done : .pending
                        )
                    )
                }
            }
            let tags = userRowTags(user, invitePending: invitePending)
            if !tags.isEmpty {
                Text(tags.joined(separator: " · "))
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                    .padding(.top, 8)
            }
        }
        .frame(minHeight: 44)
        .accessibilityLabel(user.fullName.isEmpty ? "משתמש" : user.fullName)
    }

    private func userRowTags(_ user: AdminUserListItem, invitePending: Bool) -> [String] {
        var tags = [volunteerStatusLabel(user.volunteerStatus)]
        if let otp = otpUserLabel(
            otpLoginEnabled: user.otpLoginEnabled,
            otpUsersPageEnabled: user.otpUsersPageEnabled
        ) {
            tags.append("OTP · \(otp)")
        }
        if invitePending { tags.append(INVITE_PENDING_LABEL) }
        if !user.active { tags.append(INACTIVE_ACCOUNT_LABEL) }
        return tags
    }
}

private struct AdminUserDetailSheet: View {
    let user: AdminUserListItem
    let today: String
    let actorUserId: String?
    let actorIsSuperAdmin: Bool
    let onEdit: () -> Void
    let onOtpLogin: () -> Void
    let onOtpUsersPage: () -> Void
    let onResendInvite: () -> Void
    let onCopyInvite: () -> Void
    let onSetActive: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    private var canMutate: Bool {
        canMutateAdminUser(actorIsSuperAdmin: actorIsSuperAdmin, targetRoles: user.roles)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName.isEmpty ? "משתמש" : user.fullName)
                        .font(TypeScale.section)
                        .foregroundStyle(FieldTheme.textPrimary)
                LedgerRow(label: "או״ק", value: user.callsign)
                LedgerRow(label: "טלפון", value: user.phone.map { formatPhone($0) } ?? "")
                LedgerRow(label: "דוא״ל", value: user.email)
                LedgerRow(label: FIELD_ROLES, value: roleLabels(user.roles).joined(separator: " · "))
                LedgerRow(label: FIELD_VOLUNTEER_STATUS, value: volunteerStatusLabel(user.volunteerStatus))
                if hasAvailability(active: user.active, invitePending: user.invitePending) {
                    LedgerRow(label: "זמינות", value: availabilityText(user, today: today))
                }
                if let otp = otpUserLabel(
                    otpLoginEnabled: user.otpLoginEnabled,
                    otpUsersPageEnabled: user.otpUsersPageEnabled
                ) {
                    LedgerRow(label: "OTP", value: otp)
                }
                LedgerRow(label: FIELD_VEHICLES, value: "\(user.vehicleCount)")
                if isInvitePending(active: user.active, invitePending: user.invitePending) {
                    LedgerRow(label: "חשבון", value: INVITE_PENDING_LABEL)
                } else {
                    LedgerRow(label: "חשבון", value: user.active ? "פעיל" : INACTIVE_ACCOUNT_LABEL)
                }
                ForEach(user.addresses.filter { !$0.formattedAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, id: \.formattedAddress) { address in
                    LedgerRow(
                        label: addressKindLabel(address.kind, customLabel: address.label),
                        value: address.formattedAddress
                    )
                }
                Spacer().frame(height: 8)
                if !canMutate {
                    Text(SUPER_ADMIN_LOCK_ERROR)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                } else {
                    GhostButton(title: OVERFLOW_EDIT, action: onEdit)
                    GhostButton(
                        title: otpLoginActionLabel(enabled: user.otpLoginEnabled),
                        enabled: user.otpLoginEnabled || isValidIlMobile(user.phone),
                        action: onOtpLogin
                    )
                    if canToggleUsersPageOtp(user.roles) {
                        GhostButton(
                            title: otpUsersPageActionLabel(enabled: user.otpUsersPageEnabled),
                            enabled: user.otpUsersPageEnabled || isValidIlMobile(user.phone),
                            action: onOtpUsersPage
                        )
                    }
                    if isInvitePending(active: user.active, invitePending: user.invitePending) {
                        GhostButton(title: OVERFLOW_RESEND_INVITE, action: onResendInvite)
                        GhostButton(title: OVERFLOW_COPY_INVITE_LINK, action: onCopyInvite)
                    }
                    GhostButton(
                        title: setActiveActionLabel(next: !user.active),
                        danger: user.active,
                        action: onSetActive
                    )
                    if user.id != actorUserId {
                        GhostButton(title: OVERFLOW_DELETE, danger: true, action: onDelete)
                    }
                }
            }
            .padding(16)
            }
            .background(FieldTheme.page.ignoresSafeArea())
            .navigationTitle(user.fullName.isEmpty ? "משתמש" : user.fullName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("סגירה", action: onClose)
                }
            }
        }
    }
}

private struct AdminUserFormView: View {
    let draft: InviteDraft
    let actorUserId: String?
    let addresses: [AdminAddressItem]
    let saving: Bool
    let formError: String?
    let onChange: (InviteDraft) -> Void
    let onClose: () -> Void
    let onSave: () -> Void
    let onRemoveVehicle: (AdminVehicleDraft) -> Void
    let onUnarchiveVehicle: (AdminVehicleDraft) -> Void

    private var editing: Bool { draft.id != nil }
    private var emailError: String? { editing ? nil : createUserEmailError(draft.email) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    FormField(label: FIELD_FULL_NAME, text: nameBinding)
                FormField(
                    label: FIELD_EMAIL,
                    keyboard: .emailAddress,
                    ltr: true,
                    error: emailError,
                    enabled: !editing,
                    text: emailBinding
                )
                Text(editing ? EMAIL_LOCKED_HINT : EMAIL_INVITE_HINT)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                FormField(label: FIELD_CALLSIGN, text: callsignBinding)
                FormField(
                    label: FIELD_PHONE,
                    keyboard: .phonePad,
                    mono: true,
                    text: phoneBinding
                )
                Text(PHONE_HINT)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                OptionRowSelector(
                    label: FIELD_VOLUNTEER_STATUS,
                    options: VolunteerStatus.allCases.map { ($0.rawValue, volunteerStatusLabel($0.rawValue)) },
                    selected: draft.volunteerStatus.rawValue
                ) { raw in
                    var next = draft
                    next.volunteerStatus = VolunteerStatus.fromRaw(raw)
                    onChange(next)
                }
                Text(FIELD_ROLES)
                    .font(TypeScale.label)
                    .foregroundStyle(FieldTheme.textSecondary)
                Text(ROLES_HINT)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                FieldCard {
                    ForEach(INVITABLE_ROLES, id: \.rawValue) { role in
                        let lockOwnAdmin = editing
                            && draft.id == actorUserId
                            && role == .admin
                            && draft.roles.contains(AppRole.admin.rawValue)
                        let implied = isAssignableRoleLocked(draft.roles, role: role)
                        let enabled = !lockOwnAdmin && !implied
                        Button {
                            var next = draft
                            next.roles = toggleAssignableRole(
                                draft.roles,
                                role: role,
                                checked: !draft.roles.contains(role.rawValue)
                            )
                            onChange(next)
                        } label: {
                            HStack {
                                Text(roleLabels([role.rawValue]).first ?? "")
                                    .font(TypeScale.body)
                                    .foregroundStyle(enabled ? FieldTheme.textPrimary : FieldTheme.textMuted)
                                Spacer(minLength: 8)
                                if draft.roles.contains(role.rawValue) {
                                    Text("נבחר")
                                        .font(TypeScale.caption)
                                        .foregroundStyle(FieldTheme.accent)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!enabled)
                    }
                }
                Text(FIELD_VEHICLES)
                    .font(TypeScale.label)
                    .foregroundStyle(FieldTheme.textSecondary)
                ForEach(Array(draft.vehicles.enumerated()), id: \.element.key) { index, vehicle in
                    FieldCard {
                        FormField(
                            label: VEHICLE_PLATE_LABEL,
                            keyboard: .numberPad,
                            mono: true,
                            enabled: !vehicle.archived,
                            text: plateBinding(index)
                        )
                        FormField(
                            label: VEHICLE_MODEL_LABEL,
                            enabled: !vehicle.archived,
                            text: modelBinding(index)
                        )
                        if vehicle.archived {
                            Text(VEHICLE_ARCHIVED_CAPTION)
                                .font(TypeScale.caption)
                                .foregroundStyle(FieldTheme.textMuted)
                            GhostButton(title: "שחזור מהארכיון") {
                                onUnarchiveVehicle(vehicle)
                            }
                        } else {
                            GhostButton(title: "הסרת רכב", danger: true) {
                                onRemoveVehicle(vehicle)
                            }
                        }
                    }
                }
                GhostButton(title: ADD_VEHICLE) {
                    var next = draft
                    next.vehicles.append(
                        AdminVehicleDraft(key: "new-\(Int(Date().timeIntervalSince1970 * 1000))")
                    )
                    onChange(next)
                }
                if editing {
                    ForEach(addresses.filter { !$0.formattedAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, id: \.formattedAddress) { address in
                        LedgerRow(
                            label: addressKindLabel(address.kind, customLabel: address.label),
                            value: address.formattedAddress
                        )
                    }
                }
                if let formError {
                    Text(formError)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.alert)
                }
                PrimaryButton(title: USER_SAVE_LABEL, busy: saving, action: onSave)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
            }
            .yahpazFormScroll()
            .yahpazKeyboardAccessory()
            .background(FieldTheme.page.ignoresSafeArea())
            .navigationTitle(editing ? USER_EDIT_TITLE : INVITE_TITLE)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ביטול", action: onClose)
                        .disabled(saving)
                }
            }
        }
    }

    private var nameBinding: Binding<String> {
        Binding(get: { draft.fullName }, set: { var next = draft; next.fullName = $0; onChange(next) })
    }

    private var emailBinding: Binding<String> {
        Binding(get: { draft.email }, set: { var next = draft; next.email = $0; onChange(next) })
    }

    private var callsignBinding: Binding<String> {
        Binding(get: { draft.callsign }, set: { var next = draft; next.callsign = $0; onChange(next) })
    }

    private var phoneBinding: Binding<String> {
        Binding(
            get: { draft.phone },
            set: { var next = draft; next.phone = formatPhone($0); onChange(next) }
        )
    }

    private func plateBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { draft.vehicles[index].plateNumber },
            set: { incoming in
                var next = draft
                var vehicle = next.vehicles[index]
                vehicle.plateNumber = formatPlate(incoming)
                next.vehicles[index] = vehicle
                onChange(next)
            }
        )
    }

    private func modelBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { draft.vehicles[index].model },
            set: { incoming in
                var next = draft
                var vehicle = next.vehicles[index]
                vehicle.model = incoming
                next.vehicles[index] = vehicle
                onChange(next)
            }
        )
    }
}

private struct AdminConfirmSheet: View {
    let title: String
    let message: String
    let action: String
    let danger: Bool
    let saving: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(TypeScale.section)
                .foregroundStyle(FieldTheme.textPrimary)
            Text(message)
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.textSecondary)
            if danger {
                GhostButton(title: action, enabled: !saving, danger: true, action: onConfirm)
            } else {
                PrimaryButton(title: action, busy: saving, action: onConfirm)
            }
            Button(action: onCancel) {
                Text("ביטול")
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.accent)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .disabled(saving)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FieldTheme.page.ignoresSafeArea())
    }
}

private func availabilityText(_ user: AdminUserListItem, today: String) -> String {
    let effective = effectiveAvailability(user.availability, availableFrom: user.availableFrom, today: today)
    let caption = effective == .available ? nil : availabilityReturnCaption(user.availableFrom)
    return [availabilityLabel(effective), caption].compactMap { $0 }.joined(separator: " · ")
}

private func draftFromUser(_ user: AdminUserListItem) -> InviteDraft {
    InviteDraft(
        id: user.id,
        fullName: user.fullName,
        email: user.email,
        callsign: user.callsign,
        phone: user.phone.map { formatPhone($0) } ?? "",
        volunteerStatus: VolunteerStatus.fromRaw(user.volunteerStatus),
        roles: withImpliedAssignableRoles(user.roles),
        vehicles: user.vehicles.map { vehicle in
            AdminVehicleDraft(
                key: vehicle.id,
                id: vehicle.id,
                plateNumber: formatPlate(vehicle.plateNumber),
                model: vehicle.model,
                archived: vehicle.archived
            )
        }
    )
}

private func copyInviteLink(_ actionLink: String?) -> Bool {
    let link = actionLink?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if link.isEmpty { return false }
    UIPasteboard.general.string = link
    return true
}
