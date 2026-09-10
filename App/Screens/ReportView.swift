import SwiftUI
import YahpazDomain

/// One screen for every report in the library: date range, search, rows. Report kinds
/// differ only in copy and in how the loader collapses source rows into `ReportRow`.
struct ReportView: View {
    @EnvironmentObject private var app: AppModel
    let kind: ReportKindId

    @State private var from = ""
    @State private var to = ""
    @State private var query = ""
    @State private var rangeError: String?
    @State private var actionRow: ReportRow?
    @State private var actionError: String?
    @State private var applying = false
    @State private var fillEventId: EventRoute?

    private var spec: ReportSpec { reportSpec(kind) }
    private var defaults: (String, String) { app.defaultReportRange(for: kind) }

    private var rows: [ReportRow] {
        filterReportRows(app.reportRows, query: query.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(spec.includes)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                if spec.hasDateRange {
                    HStack(alignment: .top, spacing: 12) {
                        ReturnDateField(label: "מתאריך", text: $from)
                        ReturnDateField(label: "עד תאריך", text: $to)
                    }
                    if let rangeError {
                        Text(rangeError)
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.alert)
                    }
                }
                PrimaryButton(title: REPORT_LOAD_ACTION, busy: app.reportLoading) {
                    Task { await load() }
                }
                if !app.reportRows.isEmpty {
                    FormField(
                        label: "חיפוש",
                        placeholder: spec.searchPlaceholder,
                        text: $query
                    )
                }
                results
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .yahpazFormScroll()
        .yahpazKeyboardAccessory()
        .background(FieldTheme.page.ignoresSafeArea())
        .navigationTitle(spec.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $fillEventId) { route in
            FillView(eventId: route.id)
        }
        .sheet(item: $actionRow) { row in
            reportActionSheet(row)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he"))
        }
        .refreshable { await load() }
        .task(id: kind) {
            let range = app.defaultReportRange(for: kind)
            from = returnDateToInput(app.reportFrom ?? range.0)
            to = returnDateToInput(app.reportTo ?? range.1)
            query = ""
            rangeError = nil
            if app.reportRows.isEmpty {
                await load()
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        if app.reportFailed {
            EmptyState(title: REPORT_FAILED_TITLE, actionTitle: "רענון") {
                Task { await load() }
            }
        } else if app.reportLoading && app.reportRows.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(FieldTheme.accent)
                Text(REPORT_LOADING_TITLE)
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if app.reportRows.isEmpty {
            EmptyState(title: spec.emptyTitle)
        } else if rows.isEmpty {
            EmptyState(title: "לא נמצאו שורות תואמות", actionTitle: "ניקוי חיפוש") {
                query = ""
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(reportRowSummary(rows.count))
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textSecondary)
                ForEach(rows) { row in
                    ReportRowCard(row: row, onOpen: openAction(for: row))
                }
            }
        }
    }

    private func openAction(for row: ReportRow) -> (() -> Void)? {
        if row.actionId != nil {
            return {
                actionError = nil
                actionRow = row
            }
        }
        if let eventId = row.eventId, app.ownsEventParticipation(eventId) {
            return { fillEventId = EventRoute(id: eventId) }
        }
        return nil
    }

    private func load() async {
        // Reports without a range still send the defaults; their loader ignores them.
        let fromIso = normalizeReturnDate(from) ?? (spec.hasDateRange ? nil : defaults.0)
        let toIso = normalizeReturnDate(to) ?? (spec.hasDateRange ? nil : defaults.1)
        guard let fromIso, let toIso, isValidReportRange(fromIso, toIso) else {
            rangeError = REPORT_RANGE_ERROR
            return
        }
        rangeError = nil
        await app.reloadReport(from: fromIso, to: toIso)
    }

    @ViewBuilder
    private func reportActionSheet(_ row: ReportRow) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(row.title)
                        .font(TypeScale.section)
                        .foregroundStyle(FieldTheme.textPrimary)
                    if !row.subtitle.isEmpty {
                        Text(row.subtitle)
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.textMuted)
                    }
                    if let trailing = row.trailing {
                        Text(trailing)
                            .font(TypeScale.numeric)
                            .foregroundStyle(FieldTheme.textPrimary)
                    }
                    if let confirm = row.actionConfirm {
                        Text(confirm)
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.textSecondary)
                    }
                    if let actionError {
                        Text(actionError)
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.alert)
                    }
                    PrimaryButton(title: row.actionTitle ?? "", busy: applying) {
                        guard let actionId = row.actionId else { return }
                        Task {
                            applying = true
                            let error = await app.applyReportRowAction(actionId)
                            applying = false
                            actionError = error
                            if error == nil { actionRow = nil }
                        }
                    }
                    GhostButton(title: "סגירה") { actionRow = nil }
                }
                .padding(16)
            }
            .background(FieldTheme.page.ignoresSafeArea())
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct ReportRowCard: View {
    let row: ReportRow
    var onOpen: (() -> Void)?

    var body: some View {
        let card = FieldCard {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(TypeScale.section)
                        .foregroundStyle(FieldTheme.textPrimary)
                    if !row.subtitle.isEmpty {
                        Text(row.subtitle)
                            .font(TypeScale.caption)
                            .foregroundStyle(FieldTheme.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let label = row.stampLabel {
                    StampChip(stamp: StampDescriptor(label: label, tone: row.stampTone))
                }
            }
            if let trailing = row.trailing {
                Text(trailing)
                    .font(TypeScale.numeric)
                    .foregroundStyle(FieldTheme.textPrimary)
                    .padding(.top, 8)
            }
            if let detail = row.detail {
                Text(detail)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textSecondary)
                    .padding(.top, 8)
            }
        }
        if let onOpen {
            Button(action: onOpen) { card }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
        } else {
            card
                .frame(minHeight: 44)
        }
    }
}
