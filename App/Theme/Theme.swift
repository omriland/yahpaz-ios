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

enum TypeScale {
    static let brand = Font.custom("Suez One", size: 44)
    static let title = Font.custom("IBM Plex Sans Hebrew", size: 22).weight(.bold)
    static let section = Font.custom("IBM Plex Sans Hebrew", size: 17).weight(.semibold)
    static let body = Font.custom("IBM Plex Sans Hebrew", size: 16)
    static let bodyStrong = Font.custom("IBM Plex Sans Hebrew", size: 16).weight(.semibold)
    static let label = Font.custom("IBM Plex Sans Hebrew", size: 13).weight(.medium)
    static let caption = Font.custom("IBM Plex Sans Hebrew", size: 12)
    static let stamp = Font.custom("IBM Plex Sans Hebrew", size: 12).weight(.bold)
    static let numeric = Font.custom("IBM Plex Mono", size: 16)
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
        }
    }

    var tint: Color {
        switch self {
        case .done: return FieldTheme.doneTint
        case .partial: return FieldTheme.partialTint
        case .pending: return FieldTheme.accentSubtle
        case .draft: return FieldTheme.sunken
        }
    }
}
