import SwiftUI
import YahpazDomain

struct UnitShiftsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var query = ""
    @State private var detail: ShiftListItem?
    @State private var fillEventId: EventRoute?

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shifts: [ShiftListItem] {
        let rows = trimmed.isEmpty
            ? app.unitShifts
            : app.unitShifts.filter { fieldsMatchQuery($0.unitSearchFields, query: trimmed) }
        return rows.sorted { $0.shiftDate > $1.shiftDate }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("משמרות")
                        .font(TypeScale.title)
                        .foregroundStyle(FieldTheme.textPrimary)
                    FormField(
                        label: "חיפוש",
                        placeholder: "תאריך, משמרת או אחמ״ש",
                        text: $query
                    )
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(FieldTheme.page.ignoresSafeArea())

                if app.canManageUnit {
                    PrimaryCreateFab(title: SHIFT_NEW_TITLE) {
                        app.openCreateShift()
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
            .yahpazRootNavigationBarHidden()
            .yahpazFormScroll()
            .yahpazKeyboardAccessory()
            .refreshable { await app.reloadUnitShifts() }
            .task(id: app.userId) {
                guard app.userId != nil, app.unitShifts.isEmpty else { return }
                await app.reloadUnitShifts()
            }
            .navigationDestination(item: $fillEventId) { route in
                FillView(eventId: route.id)
            }
            .sheet(item: $detail) { shift in
                unitShiftDetail(shift)
                    .environmentObject(app)
                    .environment(\.layoutDirection, .rightToLeft)
                    .environment(\.locale, Locale(identifier: "he"))
            }
            .fullScreenCover(item: Binding(
                get: { app.shiftForm },
                set: { if $0 == nil { app.closeShiftForm() } }
            )) { route in
                ShiftFormView(shiftId: route.shiftId)
                    .environmentObject(app)
                    .environment(\.layoutDirection, .rightToLeft)
                    .environment(\.locale, Locale(identifier: "he"))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if app.unitShiftsFailed {
            ScrollView {
                EmptyState(
                    title: UNIT_SHIFTS_LOAD_FAILED,
                    actionTitle: "רענון"
                ) {
                    Task { await app.reloadUnitShifts() }
                }
            }
        } else if app.unitShiftsLoading && app.unitShifts.isEmpty {
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                ProgressView()
                    .tint(FieldTheme.accent)
                Text("טוען משמרות…")
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textSecondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if shifts.isEmpty {
            ScrollView {
                EmptyState(
                    title: trimmed.isEmpty ? "אין משמרות להצגה" : "לא נמצאו משמרות תואמות",
                    actionTitle: trimmed.isEmpty ? nil : "ניקוי חיפוש"
                ) {
                    query = ""
                }
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    Text("\(shifts.count) משמרות אחרונות ביחידה")
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                    ForEach(shifts) { shift in
                        UnitShiftRow(shift: shift) { detail = shift }
                    }
                    Color.clear.frame(height: 88)
                }
            }
        }
    }

    private func unitShiftDetail(_ shift: ShiftListItem) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("פרטי המשמרת")
                        .font(TypeScale.section)
                        .foregroundStyle(FieldTheme.textPrimary)
                LedgerRow(
                    label: "תאריך",
                    value: "\(formatDate(shift.shiftDate)) (\(hebrewWeekdayLetter(shift.shiftDate)))"
                )
                LedgerRow(label: "שם משמרת", value: SHIFT_KIND_LABELS[shift.shiftKind] ?? shift.shiftKind)
                LedgerRow(label: "סוג רכב", value: VEHICLE_TYPE_LABELS[shift.vehicleType] ?? shift.vehicleType)
                if shift.vehicleType == "personal" {
                    LedgerRow(label: "לוחית", value: formatPlate(shift.personalVehicle?.plateNumber ?? ""))
                }
                LedgerRow(label: "אחמ״ש", value: shift.shiftLead?.display ?? "")
                LedgerRow(label: "מתנדבים", value: "\(shift.responders.count)")
                LedgerRow(label: "אירועים", value: "\(shift.bornEvents.count)")
                if !shift.bornEvents.isEmpty {
                    Text("אירועי המשמרת")
                        .font(TypeScale.section)
                        .foregroundStyle(FieldTheme.textPrimary)
                        .padding(.top, 8)
                    ForEach(shift.bornEvents) { event in
                        Button {
                            let id = event.id
                            detail = nil
                            DispatchQueue.main.async {
                                fillEventId = EventRoute(id: id)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.eventType?.name ?? "אירוע")
                                        .font(TypeScale.bodyStrong)
                                        .foregroundStyle(FieldTheme.textPrimary)
                                    Text(event.policeEventId ?? formatDate(event.eventDate))
                                        .font(TypeScale.caption)
                                        .foregroundStyle(FieldTheme.textMuted)
                                }
                                Spacer(minLength: 8)
                                StampChip(stamp: eventStamp(event.status))
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                if app.canManageUnit {
                    PrimaryButton(title: "עריכה") {
                        let id = shift.id
                        detail = nil
                        app.openEditShift(id)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(16)
            }
            .background(FieldTheme.page.ignoresSafeArea())
            .navigationTitle("פרטי המשמרת")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("סגירה") { detail = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct UnitShiftRow: View {
    let shift: ShiftListItem
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            FieldCard {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shift.title)
                            .font(TypeScale.section)
                            .foregroundStyle(FieldTheme.textPrimary)
                        Text("\(formatDate(shift.shiftDate)) (\(hebrewWeekdayLetter(shift.shiftDate)))")
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.textMuted)
                        if let lead = shift.shiftLead?.display {
                            Text("אחמ״ש: \(lead)")
                                .font(TypeScale.caption)
                                .foregroundStyle(FieldTheme.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    StampChip(stamp: shiftStamp(shift.status))
                }
                Text("\(shift.responders.count) מתנדבים · \(shift.bornEvents.count) אירועים")
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textSecondary)
                    .padding(.top, 8)
            }
        }
        .buttonStyle(.plain)
    }
}
