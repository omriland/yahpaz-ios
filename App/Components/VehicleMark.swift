import SwiftUI

/// Neutral vehicle mark, shown where the manufacturer is known (`slug` non-empty). Manufacturer
/// logos are third-party trademarks, so the app does not bundle them.
struct VehicleMark: View {
    let slug: String?

    var body: some View {
        if let slug, !slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Image(systemName: "car.fill")
                .font(.system(size: 18))
                .foregroundStyle(FieldTheme.textMuted)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
        }
    }
}
