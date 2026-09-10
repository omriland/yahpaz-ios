import SwiftUI
import YahpazDomain

enum FieldTheme {
    static let page = Color(hex: 0xF6F8FA)
    static let raised = Color(hex: 0xFFFFFF)
    static let sunken = Color(hex: 0xEDF1F5)
    static let textPrimary = Color(hex: 0x0F1B2D)
    static let textSecondary = Color(hex: 0x445A73)
    static let textMuted = Color(hex: 0x5B6F86)
    static let textOnAccent = Color.white
    static let accent = Color(hex: 0x1D4E89)
    static let accentHover = Color(hex: 0x17416E)
    static let accentSubtle = Color(hex: 0xEDF4FB)
    static let hairline = Color(hex: 0x0F1B2D).opacity(0.12)
    static let strong = Color(hex: 0x0F1B2D).opacity(0.55)
    static let done = Color(hex: 0x2E7D5B)
    static let doneTint = Color(hex: 0xE3F1EA)
    static let doneOnTint = Color(hex: 0x215C43)
    static let alert = Color(hex: 0xB3382F)
    static let alertTint = Color(hex: 0xF9E9E7)
    static let alertOnTint = Color(hex: 0x93291F)
    static let partial = Color(hex: 0xB07C24)
    static let partialTint = Color(hex: 0xF7EEDC)
    static let partialOnTint = Color(hex: 0x7A5410)
    static let pending = Color(hex: 0x1D4E89)
    static let draft = Color(hex: 0x5B6F86)
}

enum CommandTheme {
    static let page = Color(hex: 0x182A47)
    static let raised = Color(hex: 0x213656)
    static let sunken = Color(hex: 0x122036)
    static let overlay = Color(hex: 0x2A4168)
    static let textPrimary = Color(hex: 0xF2F6FA)
    static let textSecondary = Color(hex: 0xC3CEDC)
    static let textMuted = Color(hex: 0x9FB0C4)
    static let accent = Color(hex: 0x8FBCEB)
    static let accentFill = Color(hex: 0x2E6CB4)
    static let hairline = Color(hex: 0xF2F6FA).opacity(0.15)
    static let strong = Color(hex: 0xF2F6FA).opacity(0.45)
}

/// PostScript names, not family names. CoreText resolves a family for SwiftUI `Text`, but
/// `UIFont(name:)` returns nil for one, so anything bridged into UIKit silently loses the
/// face. Each weight maps to its own file rather than being synthesised with `.weight()`.
enum TypeScale {
    static let brand = Font.custom("SuezOne-Regular", size: 44)
    static let title = Font.custom("IBMPlexSansHebrew-Bold", size: 22)
    static let section = Font.custom("IBMPlexSansHebrew-SemiBold", size: 17)
    static let body = Font.custom("IBMPlexSansHebrew-Regular", size: 16)
    static let bodyStrong = Font.custom("IBMPlexSansHebrew-SemiBold", size: 16)
    static let label = Font.custom("IBMPlexSansHebrew-Medium", size: 13)
    static let caption = Font.custom("IBMPlexSansHebrew-Regular", size: 12)
    static let stamp = Font.custom("IBMPlexSansHebrew-Bold", size: 12)
    static let numeric = Font.custom("IBMPlexMono-Regular", size: 16)
}

/// UIKit twins for the faces used by text input.
enum UIFontScale {
    static let body = UIFont(name: "IBMPlexSansHebrew-Regular", size: 16)
        ?? .systemFont(ofSize: 16)
    static let numeric = UIFont(name: "IBMPlexMono-Regular", size: 16)
        ?? .monospacedSystemFont(ofSize: 16, weight: .regular)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension StampTone {
    var ink: Color {
        switch self {
        case .done: return FieldTheme.done
        case .partial: return FieldTheme.partial
        case .pending: return FieldTheme.pending
        case .draft: return FieldTheme.draft
        case .alert: return FieldTheme.alert
        }
    }

    var tint: Color {
        switch self {
        case .done: return FieldTheme.doneTint
        case .partial: return FieldTheme.partialTint
        case .pending: return FieldTheme.accentSubtle
        case .draft: return FieldTheme.sunken
        case .alert: return FieldTheme.alertTint
        }
    }
}
