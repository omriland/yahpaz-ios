import SwiftUI
import UIKit

/// Brand mark from `car-logos/{slug}.png`. Missing or unknown slugs render nothing.
struct CarLogo: View {
    let slug: String?

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
        }
    }

    private var image: UIImage? {
        let trimmed = slug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        if let url = Bundle.main.url(forResource: trimmed, withExtension: "png", subdirectory: "car-logos"),
           let loaded = UIImage(contentsOfFile: url.path) {
            return loaded
        }
        if let url = Bundle.main.url(forResource: trimmed, withExtension: "png"),
           let loaded = UIImage(contentsOfFile: url.path) {
            return loaded
        }
        return UIImage(named: trimmed)
    }
}
