import SwiftUI
import YahpazDomain

struct AvailabilityView: View {
    @EnvironmentObject private var app: AppModel
    var onSaved: (() -> Void)? = nil
    @State private var status: AvailabilityStatus = .available
    @State private var returnDate = ""
    @State private var error: String?
    @State private var busy = false
    @State private var autoSaved = false
    private var locked: Bool { app.impersonating }

    var body: some View {
        let isoReturn = returnDate.isEmpty ? nil : normalizeReturnDate(returnDate)
        let effective = effectiveAvailability(
            status,
            availableFrom: isoReturn,
            today: israelToday()
        )
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("זמינות")
                    .font(TypeScale.title)
                    .foregroundStyle(FieldTheme.textPrimary)
                Text("הסטטוס יוצג לאחמ״ש בשיבוץ לאירוע.")
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textSecondary)
                if locked {
                    Text(IMPERSONATION_AVAILABILITY_LOCKED)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                }
                FieldCard {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(effective == .available ? FieldTheme.done : FieldTheme.alert)
                            .frame(width: 10, height: 10)
                        Text("זמינות: \(availabilityLabel(effective))")
                            .font(TypeScale.bodyStrong)
                            .foregroundStyle(FieldTheme.textPrimary)
                        if effective == .unavailable, let caption = availabilityReturnCaption(isoReturn) {
                            Text(caption)
                                .font(TypeScale.caption)
                                .foregroundStyle(FieldTheme.textMuted)
                        }
                        Spacer(minLength: 0)
                    }
                }
                HStack(spacing: 8) {
                    AvailabilityChoice(
                        label: "זמין",
                        selected: status == .available,
                        enabled: !locked
                    ) {
                        select(.available)
                    }
                    AvailabilityChoice(
                        label: "לא זמין",
                        selected: status == .unavailable,
                        enabled: !locked
                    ) {
                        select(.unavailable)
                    }
                }
                if status == .unavailable {
                    VStack(alignment: .leading, spacing: 4) {
                        ReturnDateField(label: "תאריך חזרה (לא חובה)", enabled: !locked, text: $returnDate)
                        Text("ניתן לבחור רק תאריך עתידי")
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.textMuted)
                    }
                }
                if autoSaved && error == nil {
                    Text("השינויים נשמרים אוטומטית.")
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.done)
                }
                if let error {
                    Text(error)
                        .font(TypeScale.body)
                        .foregroundStyle(FieldTheme.alert)
                }
                PrimaryButton(title: "שמירת זמינות", busy: busy, enabled: !locked) {
                    Task { await save() }
                }
            }
            .padding(16)
        }
        .yahpazFormScroll()
        .yahpazKeyboardAccessory()
        .background(FieldTheme.page.ignoresSafeArea())
        .onAppear { syncFromProfile() }
        .task(id: returnDate) { await autosaveReturnDate() }
        .onChange(of: app.profile?.id) { _, _ in syncFromProfile() }
        .onChange(of: app.profile?.availability) { _, _ in syncFromProfile() }
        .onChange(of: app.profile?.availableFrom) { _, _ in syncFromProfile() }
    }

    private func syncFromProfile() {
        guard let profile = app.profile else { return }
        status = profile.availability
        returnDate = returnDateToInput(profile.availableFrom ?? "")
    }

    private var matchesProfile: Bool {
        guard let profile = app.profile else { return false }
        let iso = returnDate.isEmpty ? nil : normalizeReturnDate(returnDate)
        return profile.availability == status && (status == .available || profile.availableFrom == iso)
    }

    /// Picking זמין / לא זמין is the save.
    private func select(_ next: AvailabilityStatus) {
        if locked || status == next { return }
        status = next
        error = nil
        Task {
            busy = true
            let date = next == .unavailable && !returnDate.isEmpty ? returnDate : nil
            let failure = await app.saveAvailability(status: next, availableFrom: date)
            busy = false
            if let failure { error = failure } else { autoSaved = true }
        }
    }

    /// A complete return date saves 800 ms after the last keystroke.
    private func autosaveReturnDate() async {
        guard !locked, status == .unavailable, !returnDate.isEmpty else { return }
        try? await Task.sleep(nanoseconds: 800_000_000)
        guard !Task.isCancelled, normalizeReturnDate(returnDate) != nil, !matchesProfile else { return }
        if await app.saveAvailability(status: status, availableFrom: returnDate) == nil {
            autoSaved = true
            error = nil
        }
    }

    private func save() async {
        busy = true
        error = await app.saveAvailability(
            status: status,
            availableFrom: status == .unavailable && !returnDate.isEmpty ? returnDate : nil
        )
        busy = false
        if error == nil {
            onSaved?()
        }
    }
}

private struct AvailabilityChoice: View {
    let label: String
    let selected: Bool
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(selected ? TypeScale.bodyStrong : TypeScale.body)
                .foregroundStyle(
                    !enabled
                        ? FieldTheme.textMuted
                        : (selected ? FieldTheme.accent : FieldTheme.textPrimary)
                )
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? FieldTheme.accentSubtle : FieldTheme.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(selected ? FieldTheme.accent : FieldTheme.strong, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
