import SwiftUI

@main
struct YahpazApp: App {
    @StateObject private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.light)
                .task { await app.bootstrap() }
                .onOpenURL { app.applyIncomingURL($0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        app.applyIncomingURL(url)
                    }
                }
        }
    }
}
