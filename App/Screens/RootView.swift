import SwiftUI
import YahpazDomain

struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @State private var moreListVisible = false
    @State private var feedbackOpen = false
    @State private var rolePickerOpen = false
    @State private var userPickerOpen = false

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                if app.isSignedIn && (app.impersonating || app.previewRole != nil) {
                    ViewAsBanner()
                }
                ZStack(alignment: .bottomTrailing) {
                    content
                    if showFeedbackFab {
                        FeedbackMiniFab { feedbackOpen = true }
                            .padding(.trailing, 16)
                            .padding(.bottom, feedbackFabBottomPadding)
                    }
                }
            }
            if let toast = app.toast {
                ToastBanner(text: toast, tone: app.toastTone)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: app.toast)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he"))
        .fullScreenCover(isPresented: Binding(
            get: { app.privacyOpen && app.forceUpdate == nil },
            set: { if !$0 { app.closePrivacy() } }
        )) {
            PrivacyPolicyView(onClose: { app.closePrivacy() })
        }
        .sheet(isPresented: Binding(
            get: { app.optionalUpdate != nil && app.forceUpdate == nil && !app.privacyOpen },
            set: { if !$0 { dismissOptionalUpdate() } }
        )) {
            if let update = app.optionalUpdate {
                OptionalUpdateSheet(update: update, onLater: dismissOptionalUpdate)
            }
        }
        .sheet(isPresented: Binding(
            get: { feedbackOpen && app.isSignedIn && app.forceUpdate == nil },
            set: { if !$0 { feedbackOpen = false } }
        )) {
            FeedbackSheet(
                pagePath: currentFeedbackPagePath,
                onDismiss: { feedbackOpen = false },
                onHideUntilRefresh: {
                    app.hideFeedbackUntilRefresh()
                    feedbackOpen = false
                },
                onSubmit: { kind, body, audio, mime, attachments in
                    await app.submitUserFeedback(
                        kind: kind,
                        body: body,
                        pagePath: currentFeedbackPagePath,
                        audioBytes: audio,
                        audioMime: mime,
                        attachments: attachments
                    )
                }
            )
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "he"))
        }
    }

    private var trackBlocking: Bool {
        app.trackToken != nil && app.fillEventId == nil && !app.mustChangePassword
    }

    private var feedbackOverlay: String {
        feedbackOverlayName(eventForm: app.eventForm, shiftForm: app.shiftForm)
    }

    private var showFeedbackFab: Bool {
        app.isSignedIn
            && app.forceUpdate == nil
            && !app.privacyOpen
            && !trackBlocking
            && shouldShowFeedbackFab(
                hiddenUntilRefresh: app.feedbackHiddenUntilRefresh,
                overlay: feedbackOverlay,
                fillOpen: app.fillEventId != nil
            )
            && !feedbackOpen
    }

    private var stacksCreateFab: Bool {
        !moreListVisible
            && (contentTab == .events || contentTab == .shifts)
            && app.canManageUnit
            && app.eventForm == nil
            && app.shiftForm == nil
            && app.fillEventId == nil
            && !app.mustChangePassword
    }

    private var feedbackFabBottomPadding: CGFloat {
        stacksCreateFab ? 16 + 44 + 12 : 16
    }

    private var currentFeedbackPagePath: String {
        feedbackPagePathForUi(
            fillEventId: app.fillEventId,
            tab: app.tab,
            overlay: feedbackOverlay
        )
    }

    @ViewBuilder
    private var content: some View {
        if app.booting {
            ZStack {
                CommandTheme.page.ignoresSafeArea()
                ProgressView()
                    .tint(CommandTheme.accent)
            }
        } else if let update = app.forceUpdate {
            ForceUpdateView(update: update)
        } else if let token = app.trackToken, !app.isSignedIn {
            LiveTrackView(token: token)
        } else if !app.isSignedIn {
            LoginView()
        } else if app.mustChangePassword {
            ProfileView()
        } else {
            mainTabs
        }
    }

    private func dismissOptionalUpdate() {
        if let latest = app.optionalUpdate?.latestBuild {
            OptionalUpdatePrefs.skip(latestBuild: latest)
        }
        app.dismissOptionalUpdate()
    }

    private var navEntries: [MobileNavEntry] {
        mobileNavEntries(app.roles)
    }

    private var split: SplitMobileNav {
        splitMobileNav(navEntries)
    }

    private var allowedTabs: [AppModel.Tab] {
        navEntries.map { AppModel.Tab.fromMobileView($0.view) }
    }

    private var contentTab: AppModel.Tab {
        if allowedTabs.contains(app.tab) { return app.tab }
        let fallback = AppModel.Tab.fromMobileView(defaultMobileView(app.roles))
        if allowedTabs.contains(fallback) { return fallback }
        return allowedTabs.first ?? .mine
    }

    private var canViewAsUser: Bool {
        canStartImpersonation(actualRoles: app.actualRoles, impersonating: app.impersonating)
    }

    private var canViewAsRole: Bool {
        canStartRolePreview(
            actualRoles: app.actualRoles,
            impersonating: app.impersonating,
            previewing: parseRolePreviewRole(app.previewRole) != nil
        )
    }

    private var showViewAs: Bool {
        canViewAsUser || canViewAsRole || app.impersonating || app.previewRole != nil
    }

    private var showMore: Bool {
        !split.more.isEmpty || showViewAs
    }

    private var mainTabs: some View {
        VStack(spacing: 0) {
            tabBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            mobileTabBar
        }
        .background(FieldTheme.page.ignoresSafeArea())
        .onAppear { clampTabIfNeeded() }
        .onChange(of: app.roles) { _, _ in
            clampTabIfNeeded()
            if !showMore { moreListVisible = false }
        }
        .sheet(isPresented: $rolePickerOpen) {
            RolePreviewSheet(
                onClose: { rolePickerOpen = false },
                onPick: { role in
                    rolePickerOpen = false
                    Task { await app.startRolePreview(role) }
                }
            )
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "he"))
        }
        .sheet(isPresented: $userPickerOpen) {
            if let actorId = app.userId {
                ImpersonationSheet(
                    actorUserId: actorId,
                    onClose: { userPickerOpen = false },
                    onConfirm: { targetId in await app.startImpersonation(targetUserId: targetId) }
                )
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he"))
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { app.trackToken != nil },
            set: { if !$0 { app.trackToken = nil } }
        )) {
            if let token = app.trackToken {
                LiveTrackView(token: token)
                    .environmentObject(app)
            }
        }
    }

    @ViewBuilder
    private var tabBody: some View {
        if moreListVisible {
            MoreListView(
                entries: split.more,
                selectedTab: contentTab,
                canViewAsUser: canViewAsUser,
                canViewAsRole: canViewAsRole,
                impersonating: app.impersonating,
                previewing: app.previewRole != nil,
                onSelectTab: { tab in
                    moreListVisible = false
                    app.tab = tab
                },
                onViewAsUser: { userPickerOpen = true },
                onViewAsRole: { rolePickerOpen = true },
                onStopImpersonation: { Task { await app.stopImpersonation() } },
                onStopPreview: { Task { await app.stopRolePreview() } }
            )
        } else {
            switch contentTab {
            case .mine:
                InboxView()
            case .myShifts:
                MyShiftsView()
            case .contacts:
                ContactsView()
            case .events:
                UnitEventsView()
            case .shifts:
                UnitShiftsView()
            case .reports:
                ReportsCatalogView()
            case .users:
                AdminShellView()
            case .profile:
                ProfileView()
            }
        }
    }

    private var moreTabSelected: Bool {
        moreListVisible || split.more.contains {
            AppModel.Tab.fromMobileView($0.view) == contentTab
        }
    }

    private var mobileTabBar: some View {
        HStack(spacing: 0) {
            ForEach(split.tabs, id: \.view) { entry in
                let tab = AppModel.Tab.fromMobileView(entry.view)
                tabBarItem(
                    label: entry.label,
                    systemImage: iconForMobileView(entry.view),
                    selected: !moreListVisible && contentTab == tab
                ) {
                    moreListVisible = false
                    app.tab = tab
                }
            }
            if showMore {
                tabBarItem(
                    label: MOBILE_MORE_LABEL,
                    systemImage: "ellipsis",
                    selected: moreTabSelected
                ) {
                    moreListVisible = true
                }
            }
        }
        .padding(.top, 6)
        .frame(minHeight: 49)
        .background {
            FieldTheme.raised.ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(FieldTheme.hairline).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func tabBarItem(
        label: String,
        systemImage: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 22))
                Text(label)
                    .font(TypeScale.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(selected ? FieldTheme.accent : FieldTheme.textMuted)
            .frame(maxWidth: .infinity, minHeight: 49)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private func clampTabIfNeeded() {
        if app.tab != contentTab {
            app.tab = contentTab
        }
    }
}

private struct MoreListView: View {
    let entries: [MobileNavEntry]
    let selectedTab: AppModel.Tab
    let canViewAsUser: Bool
    let canViewAsRole: Bool
    let impersonating: Bool
    let previewing: Bool
    let onSelectTab: (AppModel.Tab) -> Void
    let onViewAsUser: () -> Void
    let onViewAsRole: () -> Void
    let onStopImpersonation: () -> Void
    let onStopPreview: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(MOBILE_MORE_LABEL)
                        .font(TypeScale.title)
                        .foregroundStyle(FieldTheme.textPrimary)
                        .padding(.bottom, 12)
                    ForEach(entries, id: \.view) { entry in
                        let tab = AppModel.Tab.fromMobileView(entry.view)
                        let selected = tab == selectedTab
                        Button {
                            onSelectTab(tab)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: iconForMobileView(entry.view))
                                    .font(.system(size: 22))
                                    .foregroundStyle(selected ? FieldTheme.accent : FieldTheme.textMuted)
                                    .frame(width: 28)
                                    .frame(minHeight: 44)
                                Text(entry.label)
                                    .font(selected ? TypeScale.bodyStrong : TypeScale.body)
                                    .foregroundStyle(selected ? FieldTheme.accent : FieldTheme.textPrimary)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.forward")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(FieldTheme.textMuted)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(entry.label)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        Rectangle()
                            .fill(FieldTheme.hairline)
                            .frame(height: 1)
                    }
                    if !entries.isEmpty && (canViewAsUser || canViewAsRole || impersonating || previewing) {
                        Spacer().frame(height: 16)
                    }
                    MoreViewAsRows(
                        canViewAsUser: canViewAsUser,
                        canViewAsRole: canViewAsRole,
                        impersonating: impersonating,
                        previewing: previewing,
                        onViewAsUser: onViewAsUser,
                        onViewAsRole: onViewAsRole,
                        onStopImpersonation: onStopImpersonation,
                        onStopPreview: onStopPreview
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(FieldTheme.page.ignoresSafeArea())
            .yahpazRootNavigationBarHidden()
            .accessibilityIdentifier("yahpaz-more-list")
        }
    }
}

#Preview("רשימת עוד — אחמ״ש") {
    MoreListView(
        entries: splitMobileNav(mobileNavEntries(["shift_lead"])).more,
        selectedTab: .profile,
        canViewAsUser: false,
        canViewAsRole: false,
        impersonating: false,
        previewing: false,
        onSelectTab: { _ in },
        onViewAsUser: {},
        onViewAsRole: {},
        onStopImpersonation: {},
        onStopPreview: {}
    )
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "he"))
}

private func iconForMobileView(_ view: String) -> String {
    switch view {
    case "mine": return "list.bullet.rectangle"
    case "my_shifts": return "calendar"
    case "contacts": return "person.crop.rectangle.stack"
    case "events": return "note.text"
    case "shifts": return "clock"
    case "reports": return "chart.bar.doc.horizontal"
    case "users": return "person.badge.shield.checkmark"
    case "profile": return "person.crop.circle"
    default: return "ellipsis"
    }
}
