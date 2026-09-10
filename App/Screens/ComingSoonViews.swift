import SwiftUI

struct ComingSoonPage: View {
    let title: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(TypeScale.title)
                    .foregroundStyle(FieldTheme.textPrimary)
                Spacer(minLength: 0)
                EmptyState(title: "בקרוב")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(FieldTheme.page.ignoresSafeArea())
            .yahpazRootNavigationBarHidden()
        }
    }
}

