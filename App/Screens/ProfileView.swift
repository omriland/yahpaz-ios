import SwiftUI
import YahpazDomain

struct ProfileView: View {
    @EnvironmentObject private var app: AppModel
    @State private var password = ""
    @State private var confirm = ""
    @State private var error: String?
    @State private var busy = false
    @State private var editingAvailability = false
    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("פרופיל")
                        .font(TypeScale.title)
                        .foregroundStyle(FieldTheme.textPrimary)
                    if let profile = app.profile {
                        FieldCard {
                            LedgerRow(label: "שם", value: profile.fullName)
                            LedgerRow(label: "או״ק", value: profile.callsign)
                            LedgerRow(label: "דוא״ל", value: profile.email)
                            LedgerRow(label: "טלפון", value: profile.phone ?? "")
                        }
                        if !app.mustChangePassword {
                            AvailabilityRow(
                                availability: profile.availability,
                                availableFrom: profile.availableFrom,
                                enabled: !app.impersonating
                            ) {
                                editingAvailability = true
                            }
                            VehiclesSection()
                        }
                        FieldCard {
                            Text("סיכום פעילות")
                                .font(TypeScale.section)
                                .foregroundStyle(FieldTheme.textPrimary)
                            LedgerRow(label: "אירועים", value: String(profile.lifetimeEventCount))
                            LedgerRow(label: "קילומטרים", value: String(Int(profile.lifetimeKm)))
                        }
                    }

                    if app.mustChangePassword {
                        passwordGate
                    }

                    PrivacyPolicyLink(onOpen: { app.openPrivacy() })
                    GhostButton(title: "יציאה") {
                        confirmSignOut = true
                    }
                }
                .padding(16)
            }
            .yahpazFormScroll()
            .yahpazKeyboardAccessory()
            .background(FieldTheme.page.ignoresSafeArea())
            .yahpazRootNavigationBarHidden()
            .confirmationDialog("יציאה", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("יציאה", role: .destructive) {
                    Task { await app.signOut() }
                }
                Button("ביטול", role: .cancel) {}
            } message: {
                Text("לצאת מהחשבון במכשיר זה?")
            }
            .sheet(isPresented: $editingAvailability) {
                AvailabilityView(onSaved: { editingAvailability = false })
                    .environmentObject(app)
                    .environment(\.layoutDirection, .rightToLeft)
                    .environment(\.locale, Locale(identifier: "he"))
                    .yahpazFormScroll()
                    .yahpazKeyboardAccessory()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var passwordGate: some View {
        FieldCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("יש לבחור סיסמה חדשה")
                    .font(TypeScale.section)
                    .foregroundStyle(FieldTheme.textPrimary)
                SecureFormField(
                    label: "סיסמה חדשה",
                    contentType: .newPassword,
                    submit: .next,
                    text: $password
                )
                SecureFormField(
                    label: "אימות סיסמה",
                    error: error,
                    contentType: .newPassword,
                    submit: .go,
                    onSubmit: { Task { await savePassword() } },
                    text: $confirm
                )
                PrimaryButton(title: "שמירת סיסמה", busy: busy) {
                    Task { await savePassword() }
                }
            }
        }
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

private struct AvailabilityRow: View {
    let availability: AvailabilityStatus
    let availableFrom: String?
    var enabled = true
    let onClick: () -> Void

    var body: some View {
        let effective = effectiveAvailability(availability, availableFrom: availableFrom, today: israelToday())
        let label = availabilityLabel(effective)
        let caption = effective == .unavailable ? availabilityReturnCaption(availableFrom) : nil
        Button(action: onClick) {
            FieldCard {
                HStack(spacing: 8) {
                    Circle()
                        .fill(effective == .available ? FieldTheme.done : FieldTheme.alert)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("זמינות: \(label)")
                            .font(TypeScale.bodyStrong)
                            .foregroundStyle(FieldTheme.textPrimary)
                        if let caption {
                            Text(caption)
                                .font(TypeScale.caption)
                                .foregroundStyle(FieldTheme.textMuted)
                        }
                        if !enabled {
                            Text(IMPERSONATION_AVAILABILITY_LOCKED)
                                .font(TypeScale.caption)
                                .foregroundStyle(FieldTheme.textMuted)
                        }
                    }
                    Spacer(minLength: 0)
                    if enabled {
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(FieldTheme.textMuted)
                    }
                }
                .frame(minHeight: 44)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("זמינות: \(label)")
        .accessibilityHint(enabled ? "עריכת זמינות" : IMPERSONATION_AVAILABILITY_LOCKED)
    }
}

private struct ProfileVehicleDraft: Equatable, Identifiable {
    var key: String
    var rowId: String?
    var plate: String = ""
    var model: String = ""
    var archived: Bool = false
    var isDefault: Bool = false

    var id: String { key }
}

private extension ProfileVehicle {
    func toDraft() -> ProfileVehicleDraft {
        ProfileVehicleDraft(
            key: rowId ?? "plate-\(plate)",
            rowId: rowId,
            plate: formatPlate(plate),
            model: model,
            archived: archived,
            isDefault: isDefault
        )
    }
}

private struct VehiclesSection: View {
    @EnvironmentObject private var app: AppModel
    @State private var drafts: [ProfileVehicleDraft] = []
    @State private var confirm: ProfileVehicleDraft?
    @State private var confirmMode = "delete"
    @State private var saving = false
    @State private var editingKey: String?

    private var canStar: Bool {
        canChooseDefaultVehicle(
            drafts.map {
                ProfileVehicle(
                    plate: $0.plate,
                    model: $0.model,
                    id: $0.rowId,
                    archived: $0.archived,
                    isDefault: $0.isDefault
                )
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("הרכבים שלי")
                    .font(TypeScale.section)
                    .foregroundStyle(FieldTheme.textPrimary)
                Spacer(minLength: 8)
                Button(action: addVehicle) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text(ADD_VEHICLE)
                    }
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.accent)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ADD_VEHICLE)
            }
            if canStar {
                Text("לחצו על הכוכב כדי לבחור רכב ראשי לאירועים ולמשמרות.")
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
            }
            content
        }
        .onAppear { syncDrafts(from: app.vehicles) }
        .onChange(of: app.vehicles) { _, vehicles in
            syncDrafts(from: vehicles)
        }
        .sheet(item: $confirm) { vehicle in
            confirmSheet(vehicle)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he"))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var content: some View {
        if app.vehiclesFailed && app.vehicles.isEmpty && drafts.isEmpty {
            EmptyState(
                title: "טעינת הרכבים נכשלה. בדקו את החיבור ונסו שוב.",
                actionTitle: "רענון"
            ) {
                Task { await app.reloadVehicles() }
            }
        } else if app.vehiclesLoading && app.vehicles.isEmpty && drafts.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                    .tint(FieldTheme.accent)
                    .padding(.vertical, 24)
                Spacer()
            }
        } else {
            if drafts.isEmpty {
                Text("עדיין לא רשומים רכבים.")
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textSecondary)
            }
            ForEach(drafts) { vehicle in
                let editing = isProfileVehicleEditing(id: vehicle.rowId, key: vehicle.key, editingKey: editingKey)
                if editing {
                    editingCard(vehicle)
                } else {
                    savedCard(vehicle)
                }
            }
        }
    }

    private func savedCard(_ vehicle: ProfileVehicleDraft) -> some View {
        FieldCard {
            HStack(spacing: 8) {
                CarLogo(slug: resolveCarLogoSlug(vehicle.model))
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        vehicle.archived
                            ? "\(vehicle.model.isEmpty ? "—" : vehicle.model) (בארכיון)"
                            : (vehicle.model.isEmpty ? "—" : vehicle.model)
                    )
                    .font(TypeScale.label)
                    .foregroundStyle(FieldTheme.textSecondary)
                    LicensePlateView(plate: vehicle.plate)
                }
                Spacer(minLength: 0)
                if !vehicle.archived, canStar, let id = vehicle.rowId {
                    Button {
                        if vehicle.isDefault { return }
                        Task {
                            if let error = await app.setDefaultVehicle(vehicleId: id) {
                                app.showToast(error, tone: .pending)
                                return
                            }
                            app.showToast("הרכב הראשי עודכן.", tone: .done)
                            await app.reloadVehicles()
                        }
                    } label: {
                        Image(systemName: vehicle.isDefault ? "star.fill" : "star")
                            .foregroundStyle(vehicle.isDefault ? FieldTheme.accent : FieldTheme.textMuted)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(vehicle.isDefault ? DEFAULT_VEHICLE_LABEL : SET_DEFAULT_VEHICLE_LABEL)
                }
                if vehicle.archived {
                    Button {
                        guard let id = vehicle.rowId else { return }
                        Task { await unarchive(id) }
                    } label: {
                        Image(systemName: "tray.and.arrow.up")
                            .foregroundStyle(FieldTheme.accent)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("שחזור מהארכיון")
                } else {
                    Button {
                        if let key = editingKey, key != vehicle.key {
                            Task { await persist(key) }
                        }
                        editingKey = vehicle.key
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(FieldTheme.accent)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("עריכת רכב")
                }
            }
        }
    }

    private func editingCard(_ vehicle: ProfileVehicleDraft) -> some View {
        FieldCard {
            VStack(alignment: .leading, spacing: 8) {
                FormField(
                    label: VEHICLE_PLATE_LABEL,
                    keyboard: .numberPad,
                    mono: true,
                    enabled: !vehicle.archived,
                    onSubmit: { Task { await persist(vehicle.key) } },
                    text: plateBinding(vehicle.key)
                )
                FormField(
                    label: VEHICLE_MODEL_LABEL,
                    enabled: !vehicle.archived,
                    onSubmit: { Task { await persist(vehicle.key) } },
                    text: modelBinding(vehicle.key)
                )
                if vehicle.archived {
                    Text(VEHICLE_ARCHIVED_CAPTION)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                    GhostButton(title: "שחזור מהארכיון") {
                        guard let id = vehicle.rowId else { return }
                        Task { await unarchive(id) }
                    }
                } else {
                    HStack {
                        Button {
                            Task { await persist(vehicle.key) }
                        } label: {
                            Image(systemName: "checkmark")
                                .foregroundStyle(FieldTheme.accent)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("שמירת רכב")
                        Button {
                            Task { await requestRemove(vehicle) }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(FieldTheme.alert)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("הסרת רכב")
                    }
                }
            }
        }
    }

    private func confirmSheet(_ vehicle: ProfileVehicleDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(confirmMode == "archive" ? "העברה לארכיון" : "מחיקת רכב")
                .font(TypeScale.section)
                .foregroundStyle(FieldTheme.textPrimary)
            Text(confirmMode == "archive" ? VEHICLE_ARCHIVE_CONFIRM : VEHICLE_DELETE_CONFIRM)
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.textSecondary)
            if confirmMode == "archive" {
                PrimaryButton(title: "העברה לארכיון", busy: saving) {
                    Task { await confirmArchive(vehicle) }
                }
            } else {
                GhostButton(title: "מחיקה", enabled: !saving, danger: true) {
                    Task { await confirmDelete(vehicle) }
                }
            }
            Button("ביטול") {
                if !saving { confirm = nil }
            }
            .font(TypeScale.body)
            .foregroundStyle(FieldTheme.accent)
            .disabled(saving)
            .frame(minHeight: 44)
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FieldTheme.page.ignoresSafeArea())
        .interactiveDismissDisabled(saving)
    }

    private func plateBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { drafts.first(where: { $0.key == key })?.plate ?? "" },
            set: { value in patch(key) { $0.plate = formatPlate(value) } }
        )
    }

    private func modelBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { drafts.first(where: { $0.key == key })?.model ?? "" },
            set: { value in patch(key) { $0.model = value } }
        )
    }

    private func patch(_ key: String, transform: (inout ProfileVehicleDraft) -> Void) {
        drafts = drafts.map { row in
            guard row.key == key else { return row }
            var next = row
            transform(&next)
            return next
        }
    }

    private func syncDrafts(from vehicles: [ProfileVehicle]) {
        let savedPlates = Set(vehicles.map { plateDigits($0.plate) })
        let unsaved = drafts.filter { draft in
            draft.rowId == nil && {
                let plate = plateDigits(draft.plate)
                return plate.isEmpty || !savedPlates.contains(plate)
            }()
        }
        drafts = vehicles.map { $0.toDraft() } + unsaved
    }

    private func addVehicle() {
        if let emptyNew = drafts.first(where: { $0.rowId == nil && $0.plate.isEmpty && $0.model.isEmpty }) {
            editingKey = emptyNew.key
            return
        }
        for draft in drafts where draft.rowId == nil {
            Task { await persist(draft.key) }
        }
        if let key = editingKey, let current = drafts.first(where: { $0.key == key }),
           current.rowId != nil, !current.archived {
            Task { await persist(key) }
        }
        let blank = ProfileVehicleDraft(key: "new-\(Int(Date().timeIntervalSince1970 * 1000))")
        drafts.append(blank)
        editingKey = blank.key
    }

    private func persist(_ key: String) async {
        guard let vehicle = drafts.first(where: { $0.key == key }) else { return }
        if vehicle.archived { return }
        switch vehicleFieldsForSave(plateNumber: vehicle.plate, model: vehicle.model) {
        case .error(let message):
            app.showToast(message, tone: .pending)
            return
        case .ok:
            break
        }
        let error: String?
        if vehicle.rowId == nil {
            error = await app.createOwnVehicle(plateNumber: vehicle.plate, model: vehicle.model)
        } else if let id = vehicle.rowId {
            error = await app.updateOwnVehicle(vehicleId: id, plateNumber: vehicle.plate, model: vehicle.model)
        } else {
            error = SAVE_VEHICLES_FAILED
        }
        if let error {
            app.showToast(error, tone: .pending)
            return
        }
        editingKey = nil
        if vehicle.rowId == nil {
            drafts.removeAll { $0.key == key }
            app.showToast("הרכב נשמר.", tone: .done)
        }
        await app.reloadVehicles()
    }

    private func requestRemove(_ vehicle: ProfileVehicleDraft) async {
        guard let id = vehicle.rowId, let userId = app.userId else {
            confirmMode = "delete"
            confirm = vehicle
            return
        }
        let attached = await app.isVehicleAttachedToEvents(
            userId: userId,
            vehicleId: id,
            plateNumber: vehicle.plate
        )
        confirmMode = vehicleRemoveMode(attached: attached)
        confirm = vehicle
    }

    private func confirmArchive(_ vehicle: ProfileVehicleDraft) async {
        guard let id = vehicle.rowId else {
            drafts.removeAll { $0.key == vehicle.key }
            editingKey = nil
            confirm = nil
            return
        }
        saving = true
        let error = await app.archiveOwnVehicle(vehicleId: id)
        saving = false
        if let error {
            app.showToast(error, tone: .pending)
            return
        }
        app.showToast("הרכב הועבר לארכיון", tone: .done)
        editingKey = nil
        confirm = nil
        await app.reloadVehicles()
    }

    private func confirmDelete(_ vehicle: ProfileVehicleDraft) async {
        guard let id = vehicle.rowId else {
            drafts.removeAll { $0.key == vehicle.key }
            editingKey = nil
            confirm = nil
            return
        }
        saving = true
        let error = await app.deleteOwnVehicle(vehicleId: id)
        saving = false
        if let error {
            app.showToast(error, tone: .pending)
            return
        }
        app.showToast("הרכב נמחק", tone: .done)
        editingKey = nil
        confirm = nil
        await app.reloadVehicles()
    }

    private func unarchive(_ id: String) async {
        if let error = await app.unarchiveOwnVehicle(vehicleId: id) {
            app.showToast(error, tone: .pending)
        } else {
            app.showToast("הרכב שוחזר מהארכיון", tone: .done)
            await app.reloadVehicles()
        }
    }
}
