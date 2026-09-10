import SwiftUI
import YahpazDomain

struct ReportsCatalogView: View {
    @EnvironmentObject private var app: AppModel
    var title: String = "דוחות"
    @State private var opened: OpenedReport?

    private var reports: [ReportSpec] {
        visibleReportSpecs(app.roles)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(TypeScale.title)
                        .foregroundStyle(FieldTheme.textPrimary)
                    ForEach(reports, id: \.id) { spec in
                        Button {
                            app.openReport(spec.id)
                            opened = OpenedReport(kind: spec.id)
                        } label: {
                            FieldCard {
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(spec.title)
                                            .font(TypeScale.section)
                                            .foregroundStyle(FieldTheme.textPrimary)
                                            .multilineTextAlignment(.leading)
                                        Text(spec.includes)
                                            .font(TypeScale.caption)
                                            .foregroundStyle(FieldTheme.textMuted)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "chevron.forward")
                                        .foregroundStyle(FieldTheme.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                        .accessibilityLabel(spec.title)
                    }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .yahpazFormScroll()
            .yahpazKeyboardAccessory()
            .background(FieldTheme.page.ignoresSafeArea())
            .yahpazRootNavigationBarHidden()
            .navigationDestination(item: $opened) { route in
                ReportView(kind: route.kind)
            }
        }
    }
}

private struct OpenedReport: Identifiable, Hashable {
    var kind: ReportKindId
    var id: String { kind.rawValue }
}
