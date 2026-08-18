import SwiftUI
import YahpazDomain

/// Read-only Israeli civil plate mark (IL band + serial). Height 36pt, Field plate colors.
struct LicensePlateView: View {
    let plate: String

    private var serial: String {
        formatPlate(plate)
    }

    var body: some View {
        if serial.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 0) {
                VStack(spacing: 1) {
                    IsraelFlagMark()
                        .frame(width: 16, height: 12)
                    Text("IL")
                        .font(.custom("IBM Plex Mono", size: 12).weight(.medium))
                        .foregroundStyle(Color.white)
                }
                .frame(width: 24)
                .frame(maxHeight: .infinity)
                .background(FieldTheme.accentHover)

                Text(serial)
                    .font(.custom("IBM Plex Mono", size: 16).weight(.medium))
                    .foregroundStyle(FieldTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .frame(maxHeight: .infinity)
            }
            .frame(height: 36)
            .background(Color(hex: 0xF5C400))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(FieldTheme.textPrimary, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityLabel(serial)
        }
    }
}

private struct IsraelFlagMark: View {
    var body: some View {
        Canvas { context, size in
            let band = FieldTheme.accentHover
            let paper = Color.white
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paper))
            let stripeH = size.height * (2.2 / 16)
            context.fill(
                Path(CGRect(x: 0, y: size.height * (2 / 16), width: size.width, height: stripeH)),
                with: .color(band)
            )
            context.fill(
                Path(CGRect(x: 0, y: size.height * (11.8 / 16), width: size.width, height: stripeH)),
                with: .color(band)
            )
            var up = Path()
            up.move(to: CGPoint(x: size.width * 0.5, y: size.height * (4.1 / 16)))
            up.addLine(to: CGPoint(x: size.width * (14.4 / 22), y: size.height * (10.1 / 16)))
            up.addLine(to: CGPoint(x: size.width * (7.6 / 22), y: size.height * (10.1 / 16)))
            up.closeSubpath()
            context.stroke(up, with: .color(band), lineWidth: 1)
            var down = Path()
            down.move(to: CGPoint(x: size.width * 0.5, y: size.height * (11.9 / 16)))
            down.addLine(to: CGPoint(x: size.width * (7.6 / 22), y: size.height * (5.9 / 16)))
            down.addLine(to: CGPoint(x: size.width * (14.4 / 22), y: size.height * (5.9 / 16)))
            down.closeSubpath()
            context.stroke(down, with: .color(band), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
