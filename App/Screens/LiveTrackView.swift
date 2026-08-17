import SwiftUI
import YahpazDomain

struct LiveTrackView: View {
    let token: String
    @EnvironmentObject private var app: AppModel
    @StateObject private var tracker = LocationTracker()

    var body: some View {
        ZStack {
            FieldTheme.page.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("שיתוף מיקום")
                    .font(TypeScale.title)
                    .foregroundStyle(FieldTheme.textPrimary)
                Text(tracker.statusText)
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textSecondary)
                    .multilineTextAlignment(.center)
                if tracker.sharing {
                    StampChip(stamp: .init(label: "בדרך", tone: .pending))
                }
                if tracker.ended {
                    Text("אפשר לסגור את המסך.")
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                }
                if let failed = tracker.failed, !tracker.ended {
                    Text(failed)
                        .font(TypeScale.body)
                        .foregroundStyle(FieldTheme.alert)
                        .multilineTextAlignment(.center)
                }
                GhostButton(title: "סגירה") {
                    tracker.stop()
                    app.trackToken = nil
                }
            }
            .padding(24)
        }
        .onAppear { tracker.start(token: token) }
        .onDisappear { tracker.stop() }
    }
}
