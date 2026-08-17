import SwiftUI
import YahpazDomain

struct AvailabilityView: View {
    @EnvironmentObject private var app: AppModel
    @State private var status: AvailabilityStatus = .available
    @State private var returnDate = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("זמינות")
                        .font(TypeScale.title)
                        .foregroundStyle(FieldTheme.textPrimary)
                    Text("הסטטוס מוצג לאחמ״ש בשיבוץ לאירוע.")
                        .font(TypeScale.body)
                        .foregroundStyle(FieldTheme.textSecondary)
                    current
                    Picker("זמינות", selection: $status) {
                        Text("זמין").tag(AvailabilityStatus.available)
                        Text("לא זמין").tag(AvailabilityStatus.unavailable)
                    }
                    .pickerStyle(.segmented)
                    if status == .unavailable {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("תאריך חזרה (לא חובה)")
                                .font(TypeScale.label)
                                .foregroundStyle(FieldTheme.textSecondary)
                            TextField("YYYY-MM-DD", text: $returnDate)
                                .font(TypeScale.numeric)
                                .keyboardType(.numbersAndPunctuation)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(FieldTheme.strong, lineWidth: 1)
                                )
                                .environment(\.layoutDirection, .leftToRight)
                            Text("בחרו תאריך מהמחר או השאירו ריק.")
                                .font(TypeScale.caption)
                                .foregroundStyle(FieldTheme.textMuted)
                        }
                    }
                    if let error {
                        Text(error)
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.alert)
                    }
                    PrimaryButton(title: "שמירת זמינות", busy: busy) {
                        Task { await save() }
                    }
                }
                .padding(16)
            }
            .background(FieldTheme.page.ignoresSafeArea())
            .onAppear { syncFromProfile() }
        }
    }

    private var current: some View {
        let effective = effectiveAvailability(
            status,
            availableFrom: returnDate.isEmpty ? nil : returnDate,
            today: israelToday()
        )
        return HStack {
            Circle()
                .fill(effective == .available ? FieldTheme.done : FieldTheme.alert)
                .frame(width: 10, height: 10)
            Text("זמינות: \(availabilityLabel(effective))")
                .font(TypeScale.bodyStrong)
                .foregroundStyle(FieldTheme.textPrimary)
            if effective == .unavailable, let caption = availabilityReturnCaption(returnDate.isEmpty ? nil : returnDate) {
                Text(caption)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldTheme.raised)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FieldTheme.hairline, lineWidth: 1)
        )
    }

    private func syncFromProfile() {
        guard let profile = app.profile else { return }
        status = profile.availability
        returnDate = profile.availableFrom ?? ""
    }

    private func save() async {
        busy = true
        error = await app.saveAvailability(
            status: status,
            availableFrom: status == .unavailable && !returnDate.isEmpty ? returnDate : nil
        )
        busy = false
    }
}
