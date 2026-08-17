import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack(alignment: .top) {
            content
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
    }

    @ViewBuilder
    private var content: some View {
        if app.booting {
            ZStack {
                CommandTheme.page.ignoresSafeArea()
                ProgressView()
                    .tint(CommandTheme.accent)
            }
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

    private var mainTabs: some View {
        TabView(selection: $app.tab) {
            InboxView()
                .tabItem { Label("האירועים שלי", systemImage: "list.bullet.rectangle") }
                .tag(AppModel.Tab.inbox)
            AvailabilityView()
                .tabItem { Label("זמינות", systemImage: "circle.fill") }
                .tag(AppModel.Tab.availability)
            ProfileView()
                .tabItem { Label("פרופיל", systemImage: "person.crop.circle") }
                .tag(AppModel.Tab.profile)
        }
        .tint(FieldTheme.accent)
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
}
