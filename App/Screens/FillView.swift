import SwiftUI
import YahpazDomain

struct FillView: View {
    let eventId: String
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var context: FillContext?
    @State private var draft = ResponderFillDraft.empty()
    @State private var errors = ResponderFillErrors()
    @State private var formError: String?
    @State private var loading = true
    @State private var failed = false
    @State private var savingDraft = false
    @State private var completing = false
    @State private var plateLookupGeneration = 0

    var body: some View {
        Group {
            if loading {
                ProgressView("טוען את הדיווח…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed || context == nil {
                EmptyState(
                    title: "טעינת הדיווח נכשלה. בדקו את החיבור ונסו שוב.",
                    actionTitle: "רענון"
                ) {
                    Task { await load() }
                }
            } else if let context {
                form(context)
            }
        }
        .background(FieldTheme.page.ignoresSafeArea())
        .navigationTitle("השלמת הפרטים שלי")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func form(_ context: FillContext) -> some View {
        let readOnly = context.participationStatus == .done || context.eventStatus == .done || context.isCancelled
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summary(context)
                    if context.isCancelled {
                        Text("האירוע נסגר. לא ניתן לערוך את הדיווח.")
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.textPrimary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(FieldTheme.accentSubtle)
                    }
                    if readOnly {
                        StampChip(stamp: participationStamp(context.participationStatus, isViewer: true))
                        if let updated = context.updatedAt {
                            Text("הדיווח הושלם ב־\(formatDateTime(updated)). רק אחמ״ש יכול לערוך לאחר סיום.")
                                .font(TypeScale.caption)
                                .foregroundStyle(FieldTheme.textMuted)
                        }
                    }
                    Text("הפרטים שלי")
                        .font(TypeScale.section)
                        .foregroundStyle(FieldTheme.textPrimary)
                    if context.vehicles.isEmpty {
                        Text("לא מקושר רכב למשתמש. פנו למנהל המערכת.")
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.alert)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("לוחית רישוי")
                                .font(TypeScale.label)
                                .foregroundStyle(FieldTheme.textSecondary)
                            Picker("לוחית רישוי", selection: $draft.vehiclePlate) {
                                Text("בחירת רכב").tag("")
                                ForEach(context.vehicles) { vehicle in
                                    Text(vehicle.label).tag(vehicle.plate)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(errors.vehiclePlate == nil ? FieldTheme.strong : FieldTheme.alert, lineWidth: 1)
                            )
                            .disabled(readOnly)
                            if let error = errors.vehiclePlate {
                                Text(error).font(TypeScale.caption).foregroundStyle(FieldTheme.alert)
                            }
                        }
                    }
                    FormField(
                        label: "מד אוץ התחלה",
                        keyboard: .numberPad,
                        mono: true,
                        error: errors.odometerStart,
                        text: $draft.odometerStart
                    )
                    .disabled(readOnly)
                    FormField(
                        label: "מד אוץ סיום",
                        keyboard: .numberPad,
                        mono: true,
                        error: errors.odometerEnd,
                        text: $draft.odometerEnd
                    )
                    .disabled(readOnly)
                    FormField(label: "נתיב נסיעה", error: errors.route, text: $draft.route)
                        .disabled(readOnly)
                    FormArea(label: "פירוט הטיפול", error: errors.treatmentDetail, text: $draft.treatmentDetail)
                        .disabled(readOnly)
                    treatedPlatesSection(readOnly: readOnly)
                    FormArea(label: "הערות לטיפול", minHeight: 80, text: $draft.treatmentNotes)
                        .disabled(readOnly)
                    if let formError {
                        Text(formError)
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.alert)
                    }
                }
                .padding(16)
                .padding(.bottom, 120)
            }
            if !readOnly {
                VStack(spacing: 8) {
                    PrimaryButton(title: "סיום דיווח", busy: completing) {
                        Task { await save(complete: true) }
                    }
                    GhostButton(title: "שמירת טיוטה", enabled: !savingDraft && !completing) {
                        Task { await save(complete: false) }
                    }
                }
                .padding(16)
                .background(FieldTheme.raised)
                .overlay(alignment: .top) { Rectangle().fill(FieldTheme.hairline).frame(height: 1) }
            }
        }
    }

    @ViewBuilder
    private func treatedPlatesSection(readOnly: Bool) -> some View {
        if readOnly {
            if !draft.treatedPlates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("מספרי כלי רכב")
                        .font(TypeScale.label)
                        .foregroundStyle(FieldTheme.textSecondary)
                    ForEach(draft.treatedPlates, id: \.plateNumber) { row in
                        treatedPlateRow(row, removable: false)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if !draft.treatedPlates.isEmpty {
                    ForEach(draft.treatedPlates, id: \.plateNumber) { row in
                        treatedPlateRow(row, removable: true)
                    }
                }
                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("מספרי כלי רכב")
                            .font(TypeScale.label)
                            .tracking(0.13)
                            .foregroundStyle(FieldTheme.textSecondary)
                        TextField("מספר רישוי", text: Binding(
                            get: { draft.treatedPlatePending },
                            set: { draft.treatedPlatePending = digitsOnly($0) }
                        ))
                        .font(TypeScale.numeric)
                        .foregroundStyle(FieldTheme.textPrimary)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit { commitTreatedPlate() }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(FieldTheme.raised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(errors.treatedPlates == nil ? FieldTheme.strong : FieldTheme.alert, lineWidth: 1)
                        )
                        .environment(\.layoutDirection, .leftToRight)
                        if let error = errors.treatedPlates {
                            Text(error)
                                .font(TypeScale.caption)
                                .foregroundStyle(FieldTheme.alert)
                        }
                    }
                    Button("הוספה") { commitTreatedPlate() }
                        .font(TypeScale.bodyStrong)
                        .foregroundStyle(FieldTheme.accent)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(FieldTheme.strong, lineWidth: 1)
                        )
                        .padding(.bottom, errors.treatedPlates == nil ? 0 : 18)
                }
            }
        }
    }

    private func treatedPlateRow(_ row: TreatedPlate, removable: Bool) -> some View {
        HStack(spacing: 8) {
            LicensePlateView(plate: row.plateNumber)
            if let caption = treatedPlateCaption(model: row.model, color: row.color) {
                Text(caption)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if removable {
                Button {
                    draft.treatedPlates = removeTreatedPlate(
                        draft.treatedPlates,
                        plateDigitsKey: row.plateNumber
                    )
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FieldTheme.textMuted)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("הסרת מספר \(row.plateNumber)")
            }
        }
    }

    private func summary(_ context: FillContext) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            LedgerRow(label: "תאריך", value: formatDate(context.eventDate))
            LedgerRow(label: "מספר אירוע", value: context.policeEventId ?? "")
            LedgerRow(label: "סוג אירוע", value: context.eventTypeName ?? "")
            LedgerRow(label: "כביש", value: context.roadName ?? "")
            LedgerRow(label: "מיקום", value: context.location ?? "")
            LedgerRow(label: "אחמ״ש", value: context.shiftLeadName ?? "")
        }
        .padding(16)
        .background(FieldTheme.raised)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FieldTheme.hairline, lineWidth: 1)
        )
    }

    private func commitTreatedPlate() {
        let result = YahpazDomain.commitTreatedPlate(
            pending: draft.treatedPlatePending,
            plates: draft.treatedPlates
        )
        switch result {
        case let .error(message):
            errors.treatedPlates = message
        case let .ok(plate, plates):
            draft.treatedPlates = plates
            draft.treatedPlatePending = ""
            errors.treatedPlates = nil
            enqueuePlateLookup(plate.plateNumber)
        }
    }

    private func enqueuePlateLookup(_ plateNumber: String) {
        plateLookupGeneration += 1
        let generation = plateLookupGeneration
        Task {
            let hit = await lookupPlate(plate: plateNumber)
            guard generation <= plateLookupGeneration, let hit else { return }
            let key = plateDigits(plateNumber)
            draft.treatedPlates = draft.treatedPlates.map { row in
                guard plateDigits(row.plateNumber) == key else { return row }
                return TreatedPlate(plateNumber: row.plateNumber, model: hit.model, color: hit.color)
            }
        }
    }

    private func load() async {
        loading = true
        failed = false
        do {
            context = try await YahpazAPI.shared.fetchFillContext(eventId: eventId)
            if let context {
                draft = context.draft
            } else {
                failed = true
            }
        } catch {
            failed = true
        }
        loading = false
    }

    private func save(complete: Bool) async {
        guard let context else { return }
        formError = nil
        let nextErrors = validateResponderFillDraft(
            draft,
            mode: complete ? .complete : .draft,
            allowedPlates: context.vehicles.map(\.plate),
            totalKm: context.totalKm
        )
        errors = nextErrors
        if !nextErrors.isEmpty {
            formError = nextErrors.firstMessage
            return
        }
        if complete { completing = true } else { savingDraft = true }
        let error = await YahpazAPI.shared.saveFill(context: context, draft: draft, complete: complete)
        completing = false
        savingDraft = false
        if let error {
            formError = error
            app.showToast(error, tone: .pending)
            return
        }
        app.showToast(complete ? "הדיווח הושלם" : "הטיוטה נשמרה", tone: .done)
        await app.reloadEvents()
        dismiss()
    }
}
