import SwiftUI
import YahpazDomain

struct UnitEventsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var query = ""
    @State private var detail: EventListItem?
    @State private var fillEventId: EventRoute?
    @State private var assignedEditBlocked = false
    @State private var pendingBoardIds: Set<String> = []
    @State private var catalogTargeted = false
    @State private var activeTargeted = false

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var pinnedIds: Set<String> {
        Set(app.myActiveEventPrefs.filter { $0.kind == "pin" }.map(\.eventId))
    }

    private var hiddenIds: Set<String> {
        Set(app.myActiveEventPrefs.filter { $0.kind == "hide" }.map(\.eventId))
    }

    private var lockedIds: [String] {
        guard let viewerId = app.userId else { return [] }
        return app.myActiveUnitEvents
            .filter {
                !canRemoveFromMyActive(
                    viewerId: viewerId,
                    shiftLeadId: $0.shiftLeadId,
                    status: $0.status,
                    isCancelled: $0.isCancelled
                )
            }
            .map(\.id)
    }

    private var catalogById: [String: EventListItem] {
        mergeIdentifiedLastWins(app.unitEvents, app.myActiveUnitEvents, app.myActivePinnedEvents)
    }

    private var activeEvents: [EventListItem] {
        let ids = visibleMyActiveIds(
            lockedIds: lockedIds,
            autoIds: app.myActiveUnitEvents.map(\.id),
            pinnedIds: pinnedIds,
            hiddenIds: hiddenIds
        )
        let rows = ids.compactMap { catalogById[$0] }
        if trimmed.isEmpty { return rows }
        return rows.filter { fieldsMatchQuery($0.unitSearchFields, query: trimmed) }
    }

    private var catalogEvents: [EventListItem] {
        let activeVisibleIds = Set(activeEvents.map(\.id))
        let hiddenAuto = app.myActiveUnitEvents.filter { hiddenIds.contains($0.id) && !lockedIds.contains($0.id) }
        let rows: [EventListItem]
        if trimmed.isEmpty {
            rows = app.unitEvents.filter { !activeVisibleIds.contains($0.id) }
                + hiddenAuto.filter { item in !app.unitEvents.contains(where: { $0.id == item.id }) }
        } else {
            rows = (app.unitEvents + hiddenAuto)
                .reduce(into: [EventListItem]()) { acc, item in
                    if !acc.contains(where: { $0.id == item.id }) { acc.append(item) }
                }
                .filter { fieldsMatchQuery($0.unitSearchFields, query: trimmed) }
        }
        return rows
            .filter { !activeVisibleIds.contains($0.id) }
            .sorted { $0.eventDate > $1.eventDate }
    }

    private var partitionedCatalog: (incomplete: [EventListItem], rest: [EventListItem]) {
        partitionIncompleteEvents(catalogEvents) { $0.asIncompleteSnapshot() }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("אירועים")
                        .font(TypeScale.title)
                        .foregroundStyle(FieldTheme.textPrimary)
                    FormField(
                        label: "חיפוש",
                        placeholder: "אירוע, כביש, מיקום או אחמ״ש",
                        text: $query
                    )
                    if shouldFilterUnitEventsToOwnCreated(app.roles) {
                        Toggle(isOn: Binding(
                            get: { app.showOthersCreatedEvents },
                            set: { app.setShowOthersCreatedEvents($0) }
                        )) {
                            Text(SHOW_OTHERS_CREATED_EVENTS_LABEL)
                                .font(TypeScale.body)
                                .foregroundStyle(FieldTheme.textPrimary)
                        }
                        .tint(FieldTheme.accent)
                        .frame(minHeight: 44)
                    }
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(FieldTheme.page.ignoresSafeArea())

                if app.canManageUnit {
                    PrimaryCreateFab(title: EVENT_NEW_TITLE) {
                        app.openCreateEvent()
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
            .yahpazRootNavigationBarHidden()
            .yahpazFormScroll()
            .yahpazKeyboardAccessory()
            .refreshable { await app.reloadUnitEvents() }
            .task(id: app.userId) {
                guard app.userId != nil, app.unitEvents.isEmpty, app.myActiveUnitEvents.isEmpty else { return }
                await app.reloadUnitEvents()
            }
            .navigationDestination(item: $fillEventId) { route in
                FillView(eventId: route.id)
            }
            .sheet(item: $detail) { event in
                unitEventDetail(event)
                    .environmentObject(app)
                    .environment(\.layoutDirection, .rightToLeft)
                    .environment(\.locale, Locale(identifier: "he"))
            }
            .sheet(isPresented: $assignedEditBlocked) {
                assignedBlockedSheet
                    .environment(\.layoutDirection, .rightToLeft)
                    .environment(\.locale, Locale(identifier: "he"))
            }
            .fullScreenCover(item: Binding(
                get: { app.eventForm },
                set: { if $0 == nil { app.closeEventForm() } }
            )) { route in
                EventFormView(eventId: route.eventId)
                    .environmentObject(app)
                    .environment(\.layoutDirection, .rightToLeft)
                    .environment(\.locale, Locale(identifier: "he"))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if app.unitEventsFailed {
            ScrollView {
                EmptyState(
                    title: UNIT_EVENTS_LOAD_FAILED,
                    actionTitle: "רענון"
                ) {
                    Task { await app.reloadUnitEvents() }
                }
            }
        } else if app.unitEventsLoading && app.unitEvents.isEmpty && app.myActiveUnitEvents.isEmpty {
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                ProgressView()
                    .tint(FieldTheme.accent)
                Text("טוען אירועים…")
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textSecondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    activeBoard
                    catalogBoard
                    Color.clear.frame(height: 88)
                }
            }
        }
    }

    private var activeBoard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(MY_ACTIVE_EVENTS_TITLE)
                .font(TypeScale.section)
                .foregroundStyle(FieldTheme.textPrimary)
            Text(activeHint)
                .font(TypeScale.caption)
                .foregroundStyle(activeTargeted ? FieldTheme.accent : FieldTheme.textMuted)
            if activeEvents.isEmpty && catalogTargeted == false {
                Color.clear.frame(height: 8)
            }
            ForEach(activeEvents) { event in
                let canRemove = app.userId.map {
                    canRemoveFromMyActive(
                        viewerId: $0,
                        shiftLeadId: event.shiftLeadId,
                        status: event.status,
                        isCancelled: event.isCancelled
                    )
                } ?? false
                UnitEventRow(
                    event: event,
                    boardActionTitle: MY_ACTIVE_REMOVE,
                    boardActionEnabled: canRemove && !pendingBoardIds.contains(event.id),
                    boardActionHint: canRemove ? nil : MY_ACTIVE_REMOVE_LOCKED,
                    onBoardAction: { dismissFromActive(event.id) },
                    onOpen: { tryOpenEdit(event) }
                )
                .onDrag { NSItemProvider(object: event.id as NSString) }
            }
        }
        .padding(activeTargeted ? 8 : 0)
        .background(activeTargeted ? FieldTheme.accentSubtle : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(activeTargeted ? FieldTheme.accent : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first else { return false }
            addToActive(id)
            return true
        } isTargeted: { activeTargeted = $0 }
    }

    private var catalogBoard: some View {
        let parts = partitionedCatalog
        return VStack(alignment: .leading, spacing: 8) {
            if catalogTargeted {
                Text(catalogTargeted ? MY_ACTIVE_DROP_TO_REMOVE : MY_ACTIVE_DRAG_TO_REMOVE)
                    .font(TypeScale.caption)
                    .foregroundStyle(catalogTargeted ? FieldTheme.accent : FieldTheme.textMuted)
            }
            if !catalogEvents.isEmpty {
                Text(UNIT_EVENTS_CAPTION)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                Text(MY_ACTIVE_DRAG_TO_ACTIVE)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                if !parts.incomplete.isEmpty {
                    Text(INCOMPLETE_EVENTS_HEADING)
                        .font(TypeScale.label)
                        .foregroundStyle(FieldTheme.textSecondary)
                    ForEach(parts.incomplete) { event in
                        catalogRow(event)
                    }
                }
                ForEach(parts.rest) { event in
                    catalogRow(event)
                }
            } else if catalogTargeted {
                Text(UNIT_EVENTS_CAPTION)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                Color.clear.frame(height: 48)
            } else {
                EmptyState(
                    title: trimmed.isEmpty ? "אין אירועים להצגה" : "לא נמצאו אירועים תואמים",
                    actionTitle: trimmed.isEmpty ? nil : "ניקוי חיפוש"
                ) {
                    query = ""
                }
            }
        }
        .padding(catalogTargeted ? 8 : 0)
        .background(catalogTargeted ? FieldTheme.accentSubtle : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(catalogTargeted ? FieldTheme.accent : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first else { return false }
            dismissFromActive(id)
            return true
        } isTargeted: { catalogTargeted = $0 }
    }

    private var activeHint: String {
        if activeTargeted { return MY_ACTIVE_DROP_TO_ADD }
        if activeEvents.isEmpty { return MY_ACTIVE_EVENTS_EMPTY }
        return MY_ACTIVE_REMOVE_HINT
    }

    private func catalogRow(_ event: EventListItem) -> some View {
        UnitEventRow(
            event: event,
            boardActionTitle: MY_ACTIVE_ADD,
            boardActionEnabled: !pendingBoardIds.contains(event.id),
            onBoardAction: { addToActive(event.id) },
            onOpen: { detail = event }
        )
        .onDrag { NSItemProvider(object: event.id as NSString) }
    }

    private func tryOpenEdit(_ event: EventListItem) {
        if event.blocksAssignedVolunteerEdit(viewerId: app.userId) {
            assignedEditBlocked = true
            return
        }
        app.openEditEvent(event.id)
    }

    private func addToActive(_ eventId: String) {
        if pendingBoardIds.contains(eventId) { return }
        pendingBoardIds.insert(eventId)
        Task {
            await app.addEventToMyActiveBoard(eventId)
            pendingBoardIds.remove(eventId)
        }
    }

    private func dismissFromActive(_ eventId: String) {
        if pendingBoardIds.contains(eventId) { return }
        pendingBoardIds.insert(eventId)
        Task {
            await app.removeEventFromMyActiveBoard(eventId)
            pendingBoardIds.remove(eventId)
        }
    }

    private func resolvedDetail(_ event: EventListItem) -> EventListItem {
        app.unitEvents.first(where: { $0.id == event.id })
            ?? app.myActiveUnitEvents.first(where: { $0.id == event.id })
            ?? app.myActivePinnedEvents.first(where: { $0.id == event.id })
            ?? event
    }

    private func unitEventDetail(_ event: EventListItem) -> some View {
        UnitEventDetailSheet(
            event: resolvedDetail(event),
            onClose: { detail = nil },
            onFill: { id in
                detail = nil
                DispatchQueue.main.async { fillEventId = EventRoute(id: id) }
            },
            onEdit: { current in
                if current.blocksAssignedVolunteerEdit(viewerId: app.userId) {
                    assignedEditBlocked = true
                } else {
                    detail = nil
                    app.openEditEvent(current.id)
                }
            }
        )
        .environmentObject(app)
    }

    private var assignedBlockedSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ASSIGNED_VOLUNTEER_EVENT_EDIT_ERROR)
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.textPrimary)
            PrimaryButton(title: ASSIGNED_VOLUNTEER_EVENT_EDIT_CLOSE) {
                assignedEditBlocked = false
            }
        }
        .padding(16)
        .background(FieldTheme.page.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct UnitEventRow: View {
    let event: EventListItem
    var boardActionTitle: String? = nil
    var boardActionEnabled = false
    var boardActionHint: String? = nil
    var onBoardAction: (() -> Void)? = nil
    let onOpen: () -> Void

    private var incompleteFields: [String] {
        incompleteFieldLabels(missingEventFields(event.asIncompleteSnapshot()))
    }

    private var stamp: StampDescriptor {
        if event.isCancelled { return cancelledStamp() }
        return reportingDocumentationStamp(
            event.status,
            missingKm: eventHasMissingResponderKm(event.asIncompleteSnapshot())
        )
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 0) {
                if !incompleteFields.isEmpty {
                    Rectangle()
                        .fill(FieldTheme.alert)
                        .frame(width: 3)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                if event.freeze.isFrozen {
                                    FrozenEventMark(flags: event.freeze)
                                }
                                Text(event.typeLabel.isEmpty ? "אירוע" : event.typeLabel)
                                    .font(TypeScale.section)
                                    .foregroundStyle(FieldTheme.textPrimary)
                            }
                            Text(subtitle)
                                .font(TypeScale.caption)
                                .foregroundStyle(FieldTheme.textMuted)
                            if !event.leadsCaption().isEmpty {
                                Text("אחמ״ש: \(event.leadsCaption())")
                                    .font(TypeScale.caption)
                                    .foregroundStyle(FieldTheme.textMuted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .trailing, spacing: 4) {
                            StampChip(stamp: stamp)
                            if let boardActionTitle, let onBoardAction {
                                Button(boardActionTitle, action: onBoardAction)
                                    .font(TypeScale.bodyStrong)
                                    .foregroundStyle(boardActionEnabled ? FieldTheme.accent : FieldTheme.textMuted)
                                    .disabled(!boardActionEnabled)
                                    .frame(minHeight: 44)
                                if let boardActionHint {
                                    Text(boardActionHint)
                                        .font(TypeScale.caption)
                                        .foregroundStyle(FieldTheme.textMuted)
                                }
                            }
                        }
                    }
                    if !event.responders.isEmpty {
                        let pending = event.responders.filter { $0.status != .done }.count
                        Text("\(event.responders.count) מתנדבים · \(pending) ממתינים לתיעוד")
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.textSecondary)
                    }
                    if !incompleteFields.isEmpty {
                        IncompleteFieldsNotice(
                            fields: incompleteFields,
                            spoken: incompleteNoticeLabel(missingEventFields(event.asIncompleteSnapshot()))
                        )
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FieldTheme.raised)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(FieldTheme.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        [
            formatDate(event.eventDate),
            event.policeEventId?.nilIfEmpty,
            event.road?.name?.nilIfEmpty,
            event.location?.nilIfEmpty,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

private struct IncompleteFieldsNotice: View {
    let fields: [String]
    let spoken: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(FieldTheme.hairline)
                .frame(height: 1)
            FlowLayout(spacing: 12) {
                Text(INCOMPLETE_NOTICE_MARK)
                    .font(TypeScale.label)
                    .foregroundStyle(FieldTheme.partialOnTint)
                ForEach(fields, id: \.self) { label in
                    Text(label)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textPrimary)
                        .underline(true, color: FieldTheme.partial)
                }
            }
        }
        .padding(.top, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

private struct UnitEventDetailSheet: View {
    @EnvironmentObject private var app: AppModel
    let event: EventListItem
    let onClose: () -> Void
    let onFill: (String) -> Void
    let onEdit: (EventListItem) -> Void

    @State private var expandedIds: Set<String> = []
    @State private var detailRows: UnitEventDetailRespondersWrap?
    @State private var confirmDelete = false
    @State private var deleting = false

    private var stamp: StampDescriptor {
        if event.isCancelled { return cancelledStamp() }
        return reportingDocumentationStamp(
            event.status,
            missingKm: eventHasMissingResponderKm(event.asIncompleteSnapshot())
        )
    }

    private var mine: ParticipationStatus? {
        app.userId.flatMap { event.ownParticipation(userId: $0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 8) {
                            if event.freeze.isFrozen {
                                FrozenEventMark(flags: event.freeze)
                            }
                            Text("פרטי האירוע")
                                .font(TypeScale.section)
                                .foregroundStyle(FieldTheme.textPrimary)
                        }
                        Spacer(minLength: 8)
                        StampChip(stamp: stamp)
                    }
                LedgerRow(label: "תאריך", value: formatDate(event.eventDate))
                LedgerRow(label: "מספר אירוע", value: event.policeEventId ?? "")
                LedgerRow(label: "סוג אירוע", value: event.typeLabel)
                LedgerRow(label: "כביש", value: event.road?.name ?? "")
                LedgerRow(label: "מיקום", value: event.location ?? "")
                LedgerRow(label: "נת״צ", value: event.busLane ? "כן" : "לא")
                if event.origin == "shift", let detailRows {
                    LedgerRow(label: "מספרי כלי רכב", value: treatedPlatesLabel(shiftEventPlates(detailRows)))
                }
                LedgerRow(label: "סטטוס", value: stamp.label)
                EventLeadLedgerRows(main: event.shiftLead, secondaries: event.secondaryLeads)
                Text("מתנדבים (\(event.responders.count))")
                    .font(TypeScale.section)
                    .foregroundStyle(FieldTheme.textPrimary)
                if event.responders.isEmpty {
                    Text("טרם שובצו מתנדבים לאירוע")
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                } else if detailRows == nil {
                    ProgressView("טוען מתנדבים…")
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    ForEach(detailRows?.responders ?? []) { row in
                        UnitEventResponderRow(
                            row: row,
                            showTreatedPlates: event.origin != "shift",
                            isViewer: row.responderId == app.userId,
                            expanded: expandedIds.contains(row.id)
                        ) {
                            if expandedIds.contains(row.id) {
                                expandedIds.remove(row.id)
                            } else {
                                expandedIds.insert(row.id)
                            }
                        }
                    }
                }
                if let mine, let label = mineFillCtaLabel(mine) {
                    PrimaryButton(title: label) { onFill(event.id) }
                }
                if app.canManageUnit {
                    PrimaryButton(title: EVENT_EDIT_TITLE) { onEdit(event) }
                }
                if canDeleteUnassignedEvent(
                    canManageUnit: app.canManageUnit,
                    responderCount: event.responders.count,
                    viewerIsAdmin: app.canAdmin,
                    viewerId: app.userId,
                    shiftLeadId: event.shiftLeadId
                ) {
                    GhostButton(
                        title: EVENT_DELETE_TITLE,
                        enabled: !deleting,
                        danger: true
                    ) {
                        confirmDelete = true
                    }
                }
            }
            .padding(16)
            }
            .background(FieldTheme.page.ignoresSafeArea())
            .navigationTitle("פרטי האירוע")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("סגירה", action: onClose)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .confirmationDialog(EVENT_DELETE_TITLE, isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(EVENT_DELETE_ACTION, role: .destructive) {
                Task {
                    deleting = true
                    if let error = await app.deleteUnitEvent(event.id) {
                        app.showToast(error, tone: .pending)
                        confirmDelete = false
                    } else {
                        onClose()
                    }
                    deleting = false
                }
            }
            Button("ביטול", role: .cancel) {}
        } message: {
            Text(EVENT_DELETE_CONFIRM)
        }
        .task(id: event.id) {
            expandedIds = []
            detailRows = try? await YahpazAPI.shared.fetchUnitEventDetailResponders(eventId: event.id)
        }
    }
}

private struct EventLeadLedgerRows: View {
    let main: PersonName?
    let secondaries: [EventSecondaryLeadRow]

    var body: some View {
        let mapped = secondaries.map { $0.asDomain() }
        LedgerRow(
            label: eventLeadFieldLabel(hasSecondaries: !mapped.isEmpty),
            value: formatLeadPerson(main?.fullName, callsign: main?.callsign)
        )
        ForEach(mapped) { row in
            LedgerRow(label: SECONDARY_LEAD_LABEL, value: row.display)
        }
    }
}

private struct UnitEventResponderRow: View {
    let row: UnitEventDetailResponderRow
    var showTreatedPlates: Bool
    var isViewer: Bool
    var expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            FieldCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.profile?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "מתנדב")
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.textPrimary)
                        if let callsign = row.profile?.callsign?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !callsign.isEmpty
                        {
                            Text("או״ק \(callsign)")
                                .font(TypeScale.caption)
                                .foregroundStyle(FieldTheme.textMuted)
                        }
                    }
                    Spacer(minLength: 8)
                    StampWithNote(
                        stamp: participationStamp(row.status, isViewer: isViewer),
                        note: isViewer ? leadKmPendingNote(row.status, totalKm: row.totalKm) : nil
                    )
                    Image(systemName: expanded ? "chevron.down" : "chevron.left")
                        .foregroundStyle(FieldTheme.accent)
                }
                if expanded {
                    VStack(alignment: .leading, spacing: 0) {
                        LedgerRow(label: "זמן התחלה", value: formatTime(row.startedAt) ?? "")
                        LedgerRow(label: "זמן סיום", value: formatTime(row.endedAt) ?? "")
                        if let km = row.totalKm {
                            LedgerRow(label: "קילומטרים", value: "\(formatNumber(km)) ק״מ")
                        }
                        LedgerRow(label: "אמצעים", value: row.emergencyMeans ? "כן" : "לא")
                        let treated = treatedVehiclesLabel(row.treated)
                        if !treated.isEmpty {
                            LedgerRow(label: "רכבים שטופלו", value: treated)
                        }
                        if showTreatedPlates {
                            let plates = treatedPlatesLabel(row.treatedPlates)
                            if !plates.isEmpty {
                                LedgerRow(label: "מספרי כלי רכב", value: plates)
                            }
                        }
                        if let plate = row.vehiclePlate?.trimmingCharacters(in: .whitespacesAndNewlines), !plate.isEmpty {
                            LedgerRow(label: "לוחית רישוי", value: formatPlate(plate))
                        }
                        if let start = row.odometerStart {
                            LedgerRow(label: "מד אוץ התחלה", value: formatNumber(start))
                        }
                        if let end = row.odometerEnd {
                            LedgerRow(label: "מד אוץ סיום", value: formatNumber(end))
                        }
                        if let route = row.route?.trimmingCharacters(in: .whitespacesAndNewlines), !route.isEmpty {
                            LedgerRow(label: "נתיב נסיעה", value: route)
                        }
                    }
                    .padding(.top, 8)
                    if let detail = row.treatmentDetail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
                        Text("פירוט הטיפול")
                            .font(TypeScale.label)
                            .foregroundStyle(FieldTheme.textSecondary)
                            .padding(.top, 8)
                        Text(detail)
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.textPrimary)
                    }
                    if let notes = row.treatmentNotes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                        Text("הערות לטיפול")
                            .font(TypeScale.label)
                            .foregroundStyle(FieldTheme.textSecondary)
                            .padding(.top, 8)
                        Text(notes)
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.textPrimary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private func treatedVehiclesLabel(_ treated: [TreatedVehicleKindRow]) -> String {
    treated.compactMap { row in
        guard let qty = row.quantity else { return nil }
        let name = row.kind?.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "רכב"
        return "\(name) × \(qty)"
    }.joined(separator: ", ")
}

private func treatedPlatesLabel(_ plates: [EventTreatedPlateRow]) -> String {
    plates.compactMap { plate in
        plate.plateNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty.map(formatPlate)
    }.joined(separator: ", ")
}

private func shiftEventPlates(_ detail: UnitEventDetailRespondersWrap) -> [EventTreatedPlateRow] {
    var seen = Set<String>()
    return (detail.sharedPlates + detail.responders.flatMap(\.treatedPlates)).filter { row in
        guard let plate = row.plateNumber else { return false }
        return seen.insert(plateDigits(plate)).inserted
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
