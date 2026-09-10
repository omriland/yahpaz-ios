import SwiftUI
import YahpazDomain

struct AdminShellView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    segmentChip(
                        label: USERS_TITLE,
                        selected: app.adminHubSegment == .users
                    ) {
                        app.adminHubSegment = .users
                    }
                    segmentChip(
                        label: ADMIN_SEGMENT_REPORTS_LABEL,
                        selected: app.adminHubSegment == .reports
                    ) {
                        app.adminHubSegment = .reports
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            Group {
                switch app.adminHubSegment {
                case .users:
                    AdminUsersView()
                case .reports:
                    ReportsCatalogView(title: ADMIN_SEGMENT_REPORTS_LABEL)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(FieldTheme.page.ignoresSafeArea())
    }

    private func segmentChip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(TypeScale.label)
                .foregroundStyle(selected ? FieldTheme.accent : FieldTheme.textSecondary)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(selected ? FieldTheme.accentSubtle : FieldTheme.sunken)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
