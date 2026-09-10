import SwiftUI
import YahpazDomain

struct InboxView: View {
    @EnvironmentObject private var app: AppModel
    @State private var tab: MineInboxTab = .pending
    @State private var loggedQuery = ""
    @State private var windowsLoaded = 1
    @State private var fillEventId: EventRoute?
    @State private var detailEvent: EventListItem?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                header
                tabs
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .background(FieldTheme.page.ignoresSafeArea())
            .yahpazRootNavigationBarHidden()
            .yahpazFormScroll()
            .yahpazKeyboardAccessory()
            .navigationDestination(item: $fillEventId) { route in
                FillView(eventId: route.id)
            }
            .sheet(item: $detailEvent) { event in
                EventSummarySheet(
                    event: event,
                    userId: app.userId,
                    onFill: {
                        let id = event.id
                        detailEvent = nil
                        DispatchQueue.main.async {
                            fillEventId = EventRoute(id: id)
                        }
                    }
                )
            }
            .refreshable { await app.reloadEvents() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("האירועים שלי")
                .font(TypeScale.title)
                .foregroundStyle(FieldTheme.textPrimary)
            Text(openMineSummary(count: pending.count, ready: !app.eventsLoading))
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.textSecondary)
            if fuelNoteNeeded(openCount: pending.count) {
                Text(FUEL_NOTE)
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textPrimary)
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            tabChip(.pending, minePendingTabLabel(count: pending.count))
            tabChip(.logged, MINE_LOGGED_TAB_LABEL)
        }
    }

    private func tabChip(_ value: MineInboxTab, _ label: String) -> some View {
        Button {
            tab = value
        } label: {
            Text(label)
                .font(TypeScale.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(tab == value ? FieldTheme.accent : FieldTheme.textSecondary)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(tab == value ? FieldTheme.accentSubtle : FieldTheme.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(tab == value ? FieldTheme.accent : FieldTheme.strong, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if app.eventsFailed {
            ScrollView {
                EmptyState(
                    title: "טעינת האירועים נכשלה. בדקו את החיבור ונסו שוב.",
                    actionTitle: "רענון"
                ) {
                    Task { await app.reloadEvents() }
                }
            }
        } else if app.eventsLoading && app.events.isEmpty {
            ProgressView("טוען את הדיווחים שלך…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if tab == .pending {
            pendingList
        } else {
            loggedList
        }
    }

    @ViewBuilder
    private var pendingList: some View {
        if pending.isEmpty {
            ScrollView {
                EmptyState(
                    title: MINE_PENDING_EMPTY_TITLE,
                    caption: MINE_PENDING_EMPTY_CAPTION,
                    actionTitle: logged.isEmpty ? nil : MINE_PENDING_EMPTY_VIEW_LOGGED
                ) {
                    tab = .logged
                }
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(pendingBlocks, id: \.id) { block in
                        switch block {
                        case .single(let event):
                            EventCardView(
                                event: event,
                                userId: app.userId,
                                onOpen: { detailEvent = event },
                                onFill: { fillEventId = EventRoute(id: event.id) }
                            )
                        case .shift(let title, let events):
                            ShiftGroupView(
                                title: title,
                                caption: shiftGroupPendingCaption(count: events.count),
                                startsOpen: shiftGroupShouldStartOpen(pendingCount: events.count)
                            ) {
                                ForEach(events) { event in
                                    EventCardView(
                                        event: event,
                                        userId: app.userId,
                                        onOpen: { detailEvent = event },
                                        onFill: { fillEventId = EventRoute(id: event.id) }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private var loggedList: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("חיפוש לפי מספר אירוע, כביש, מיקום", text: $loggedQuery)
                .font(TypeScale.body)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(FieldTheme.strong, lineWidth: 1)
                )
            Text("תועדו · 30 יום אחרונים")
                .font(TypeScale.caption)
                .foregroundStyle(FieldTheme.textMuted)
            if filteredLogged.isEmpty {
                ScrollView {
                    EmptyState(
                        title: loggedQuery.trimmingCharacters(in: .whitespaces).isEmpty
                            ? MINE_LOGGED_EMPTY_TITLE
                            : mineLoggedNoResultsTitle(query: loggedQuery.trimmingCharacters(in: .whitespacesAndNewlines)),
                        actionTitle: loggedQuery.isEmpty ? nil : "ניקוי חיפוש"
                    ) {
                        loggedQuery = ""
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredLogged) { event in
                            Button {
                                detailEvent = event
                            } label: {
                                LoggedRow(event: event, query: loggedQuery, userId: app.userId)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(FieldTheme.raised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(FieldTheme.hairline, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    if hasMoreLogged {
                        GhostButton(title: "הצג 30 יום נוספים") {
                            windowsLoaded += 1
                        }
                        .padding(.top, 12)
                    }
                }
            }
        }
    }

    private var pending: [EventListItem] {
        app.events.filter { event in
            guard let userId = app.userId else { return false }
            return mineInboxIsOpen(
                event.ownParticipation(userId: userId),
                totalKm: event.ownTotalKm(userId: userId)
            )
        }
        .sorted { $0.eventDate > $1.eventDate }
    }

    private var loggedWindow: MineListSections<MineListEvent> {
        guard let userId = app.userId else {
            return MineListSections(pending: [], logged: [], hasMoreLogged: false)
        }
        return partitionMineList(
            app.events.map {
                MineListEvent(
                    id: $0.id,
                    date: $0.eventDate,
                    participation: $0.ownParticipation(userId: userId) ?? .pending,
                    totalKm: $0.ownTotalKm(userId: userId)
                )
            },
            today: israelToday(),
            windowsLoaded: windowsLoaded
        )
    }

    private var logged: [EventListItem] {
        let ids = Set(loggedWindow.logged.map(\.id))
        return app.events.filter { ids.contains($0.id) }.sorted { $0.eventDate > $1.eventDate }
    }

    private var hasMoreLogged: Bool { loggedWindow.hasMoreLogged }

    private var filteredLogged: [EventListItem] {
        let query = loggedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return logged }
        return logged.filter { mineEventMatchesQuery($0.searchFields, query: query) }
    }

    private var pendingBlocks: [InboxBlock] {
        var blocks: [InboxBlock] = []
        var index = 0
        let items = pending
        while index < items.count {
            let event = items[index]
            if event.origin == "shift", let shiftId = event.shiftId {
                var grouped = [event]
                index += 1
                while index < items.count,
                      items[index].origin == "shift",
                      items[index].shiftId == shiftId
                {
                    grouped.append(items[index])
                    index += 1
                }
                blocks.append(.shift(title: event.shiftGroupTitle, events: grouped))
            } else {
                blocks.append(.single(event))
                index += 1
            }
        }
        return blocks
    }
}

enum MineInboxTab { case pending, logged }

enum InboxBlock: Identifiable {
    case single(EventListItem)
    case shift(title: String, events: [EventListItem])

    var id: String {
        switch self {
        case .single(let event): return event.id
        case .shift(let title, let events): return "shift-\(title)-\(events.first?.id ?? "")"
        }
    }
}

struct EventRoute: Identifiable, Hashable {
    var id: String
}

struct ShiftGroupView<Content: View>: View {
    let title: String
    let caption: String
    var startsOpen: Bool
    @ViewBuilder var content: Content
    @State private var open: Bool?

    var body: some View {
        let isOpen = open ?? startsOpen
        VStack(alignment: .leading, spacing: 8) {
            Button {
                open = !isOpen
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(TypeScale.label)
                        .foregroundStyle(FieldTheme.textSecondary)
                    Text(caption)
                        .font(TypeScale.body)
                        .foregroundStyle(FieldTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen {
                content
            }
        }
    }
}

struct EventCardView: View {
    let event: EventListItem
    var userId: String?
    var onOpen: () -> Void
    var onFill: () -> Void

    var body: some View {
        let mine = userId.flatMap { event.ownParticipation(userId: $0) } ?? .pending
        let stamp = event.isCancelled ? cancelledStamp() : participationStamp(mine, isViewer: true)
        let overdue = isMineFillOverdue(
            isCancelled: event.isCancelled,
            participationStatus: mine,
            fillCompletableAt: userId.flatMap { event.ownFillCompletableAt(userId: $0) }
        )
        let regular = event.origin != "shift"
        let cardFill: Color = {
            if overdue { return FieldTheme.alertTint }
            if regular { return FieldTheme.accentSubtle }
            return FieldTheme.raised
        }()
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpen) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            if overdue {
                                Image(systemName: "hourglass")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(FieldTheme.alert)
                                    .accessibilityLabel(OVERDUE_FILL_CARD_TIP)
                            }
                            Text(event.typeLabel.isEmpty ? "אירוע" : event.typeLabel)
                                .font(TypeScale.section)
                                .foregroundStyle(FieldTheme.textPrimary)
                        }
                        Text(metaLine)
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.textMuted)
                    }
                    Spacer()
                    StampWithNote(
                        stamp: stamp,
                        note: userId.flatMap { leadKmPendingNote(mine, totalKm: event.ownTotalKm(userId: $0)) }
                    )
                }
                // `.plain` draws no background, so without an explicit shape the Spacer
                // between the title and the stamp is dead space and the card ignores taps
                // anywhere in its middle.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let fill = mineFillCtaLabel(mine) {
                PrimaryButton(title: fill, action: onFill)
            }
        }
        .padding(16)
        .background(cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FieldTheme.hairline, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            if overdue || regular {
                (overdue ? FieldTheme.alert : FieldTheme.accent)
                    .frame(width: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var metaLine: String {
        [formatDate(event.eventDate), event.policeEventId]
            .compactMap { $0?.isEmpty == false ? $0 : ($0 == nil ? nil : $0) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

private let searchHitYellow = Color(hex: 0xFFF59D)

struct HighlightedText: View {
    let text: String
    let query: String
    var font: Font
    var color: Color

    var body: some View {
        let ranges = searchHighlightRanges(text, query: query)
        if ranges.isEmpty {
            Text(text)
                .font(font)
                .foregroundStyle(color)
        } else {
            Text(highlighted(ranges))
                .font(font)
                .foregroundStyle(color)
        }
    }

    private func highlighted(_ ranges: [TextHighlightRange]) -> AttributedString {
        var result = AttributedString(text)
        for range in ranges {
            guard range.start >= 0, range.endExclusive <= text.utf16.count else { continue }
            let start = String.Index(utf16Offset: range.start, in: text)
            let end = String.Index(utf16Offset: range.endExclusive, in: text)
            if let lower = AttributedString.Index(start, within: result),
               let upper = AttributedString.Index(end, within: result)
            {
                result[lower..<upper].backgroundColor = searchHitYellow
            }
        }
        return result
    }
}

struct LoggedRow: View {
    let event: EventListItem
    var query: String
    var userId: String?

    var body: some View {
        let place = [event.road?.name, event.location]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " · ")
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HighlightedText(
                    text: event.typeLabel.isEmpty ? "אירוע" : event.typeLabel,
                    query: query,
                    font: TypeScale.bodyStrong,
                    color: FieldTheme.textPrimary
                )
                HighlightedText(
                    text: [formatDate(event.eventDate), event.policeEventId]
                        .compactMap { $0?.isEmpty == false ? $0 : nil }
                        .joined(separator: " · "),
                    query: query,
                    font: TypeScale.caption,
                    color: FieldTheme.textMuted
                )
                if !place.isEmpty {
                    HighlightedText(
                        text: place,
                        query: query,
                        font: TypeScale.caption,
                        color: FieldTheme.textMuted
                    )
                }
            }
            Spacer()
            StampWithNote(
                stamp: participationStamp(.done, isViewer: true),
                note: userId.flatMap {
                    leadKmPendingNote(.done, totalKm: event.ownTotalKm(userId: $0))
                }
            )
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(FieldTheme.hairline).frame(height: 1)
        }
    }
}

struct EventSummarySheet: View {
    let event: EventListItem
    var userId: String?
    var onFill: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let mine = userId.flatMap { event.ownParticipation(userId: $0) } ?? .pending
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        LedgerRow(label: "תאריך", value: formatDate(event.eventDate))
                        LedgerRow(label: "מספר אירוע", value: event.policeEventId ?? "")
                        LedgerRow(label: "סוג אירוע", value: event.typeLabel)
                        LedgerRow(label: "כביש", value: event.road?.name ?? "")
                        LedgerRow(label: "מיקום", value: event.location ?? "")
                        LedgerRow(label: "אחמ״ש", value: event.shiftLead?.display ?? "")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("מתנדבים (\(event.responders.count))")
                            .font(TypeScale.section)
                            .foregroundStyle(FieldTheme.textPrimary)
                        ForEach(event.responders) { row in
                            HStack {
                                Text(row.profile?.display ?? "מתנדב")
                                    .font(TypeScale.body)
                                    .foregroundStyle(FieldTheme.textPrimary)
                                Spacer()
                                StampWithNote(
                                    stamp: participationStamp(
                                        row.status,
                                        isViewer: row.responderId == userId
                                    ),
                                    note: row.responderId == userId
                                        ? leadKmPendingNote(row.status, totalKm: row.totalKm)
                                        : nil
                                )
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    if let fill = mineFillCtaLabel(mine), let onFill {
                        PrimaryButton(title: fill, action: onFill)
                    }
                }
                .padding(16)
            }
            .background(FieldTheme.page)
            .navigationTitle("פרטי האירוע")
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
