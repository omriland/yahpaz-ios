import SwiftUI
import YahpazDomain

struct MyShiftsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var windowsLoaded = 1
    @State private var selected: ShiftListItem?
    @State private var fillEventId: EventRoute?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("המשמרות שלי")
                    .font(TypeScale.title)
                    .foregroundStyle(FieldTheme.textPrimary)
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .background(FieldTheme.page.ignoresSafeArea())
            .yahpazRootNavigationBarHidden()
            .navigationDestination(item: $fillEventId) { route in
                FillView(eventId: route.id)
            }
            .sheet(item: $selected) { shift in
                ShiftSummarySheet(shift: shift)
            }
            .refreshable { await app.reloadShifts() }
            .task(id: app.userId) {
                guard app.userId != nil, app.shifts.isEmpty else { return }
                await app.reloadShifts()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if app.shiftsFailed {
            ScrollView {
                EmptyState(
                    title: "טעינת המשמרות נכשלה. בדקו את החיבור ונסו שוב.",
                    actionTitle: "רענון"
                ) {
                    Task { await app.reloadShifts() }
                }
            }
        } else if app.shiftsLoading && app.shifts.isEmpty {
            ProgressView("טוען משמרות…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if app.shifts.isEmpty {
            ScrollView {
                EmptyState(title: MINE_SHIFTS_NONE)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ShiftSection(
                        title: "משמרות ממתינות לתיעוד",
                        empty: MINE_SHIFTS_PENDING_EMPTY,
                        items: pending,
                        onOpen: { selected = $0 },
                        onEvent: { fillEventId = EventRoute(id: $0) }
                    )
                    if !future.isEmpty {
                        ShiftSection(
                            title: "משמרות עתידיות",
                            empty: nil,
                            items: future,
                            onOpen: { selected = $0 },
                            onEvent: { fillEventId = EventRoute(id: $0) }
                        )
                    }
                    ShiftSection(
                        title: "משמרות שתועדו",
                        empty: MINE_SHIFTS_LOGGED_EMPTY,
                        items: logged,
                        onOpen: { selected = $0 },
                        onEvent: { fillEventId = EventRoute(id: $0) }
                    )
                    if sections.hasMoreLogged {
                        GhostButton(title: "הצג 30 יום נוספים") {
                            windowsLoaded += 1
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private var sections: MineShiftSections<MineShiftItem> {
        partitionMineShifts(
            app.shifts.map(\.mineItem),
            today: israelToday(),
            windowsLoaded: windowsLoaded
        )
    }

    private var pending: [ShiftListItem] { mapped(sections.pending) }
    private var future: [ShiftListItem] { mapped(sections.future) }
    private var logged: [ShiftListItem] { mapped(sections.logged) }

    private func mapped(_ items: [MineShiftItem]) -> [ShiftListItem] {
        let byId = keyedLastWins(app.shifts)
        return items.compactMap { byId[$0.id] }
    }
}

private struct ShiftSection: View {
    let title: String
    let empty: String?
    let items: [ShiftListItem]
    let onOpen: (ShiftListItem) -> Void
    let onEvent: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(TypeScale.label)
                .foregroundStyle(FieldTheme.textSecondary)
            if items.isEmpty, let empty {
                Text(empty)
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textSecondary)
            } else {
                ForEach(items) { shift in
                    ShiftCard(shift: shift, onOpen: { onOpen(shift) }, onEvent: onEvent)
                }
            }
        }
    }
}

private struct ShiftCard: View {
    let shift: ShiftListItem
    let onOpen: () -> Void
    let onEvent: (String) -> Void
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { open.toggle() } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shift.title)
                            .font(TypeScale.section)
                            .foregroundStyle(FieldTheme.textPrimary)
                        Text("\(shift.responders.count) כוננים · \(shift.bornEvents.count) אירועים")
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.textSecondary)
                        Text("\(formatDate(shift.shiftDate)) (\(hebrewWeekdayLetter(shift.shiftDate)))")
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.textMuted)
                    }
                    Spacer()
                    StampChip(stamp: shiftStamp(shift.status))
                }
            }
            .buttonStyle(.plain)
            GhostButton(title: "פרטי המשמרת", action: onOpen)
            if open {
                if shift.bornEvents.isEmpty {
                    Text("אין אירועים ממשמרת זו.")
                        .font(TypeScale.body)
                        .foregroundStyle(FieldTheme.textSecondary)
                } else {
                    ForEach(shift.bornEvents) { event in
                        Button {
                            onEvent(event.id)
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
                                Spacer()
                                StampChip(stamp: eventStamp(event.status))
                            }
                            .padding(12)
                            .background(FieldTheme.sunken)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(FieldTheme.raised)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FieldTheme.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ShiftSummarySheet: View {
    let shift: ShiftListItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    LedgerRow(
                        label: "תאריך",
                        value: "\(formatDate(shift.shiftDate)) (\(hebrewWeekdayLetter(shift.shiftDate)))"
                    )
                    LedgerRow(label: "שם משמרת", value: SHIFT_KIND_LABELS[shift.shiftKind] ?? shift.shiftKind)
                    LedgerRow(label: "רכב", value: VEHICLE_TYPE_LABELS[shift.vehicleType] ?? shift.vehicleType)
                    if shift.vehicleType == "personal" {
                        LedgerRow(label: "לוחית", value: formatPlate(shift.personalVehicle?.plateNumber ?? ""))
                    }
                    LedgerRow(label: "אחמ״ש", value: shift.shiftLead?.display ?? "")
                    LedgerRow(label: "כוננים", value: "\(shift.responders.count)")
                    LedgerRow(label: "אירועים", value: "\(shift.bornEvents.count)")
                }
                .padding(16)
            }
            .background(FieldTheme.page)
            .navigationTitle("פרטי המשמרת")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("סגירה") { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
