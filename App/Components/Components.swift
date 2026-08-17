import SwiftUI
import YahpazDomain

struct StampChip: View {
    let stamp: StampDescriptor

    var body: some View {
        Text(stamp.label)
            .font(TypeScale.stamp)
            .tracking(0.72)
            .foregroundStyle(stamp.tone.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(stamp.tone.tint)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(stamp.tone.ink.opacity(0.25), lineWidth: 1)
            )
            .accessibilityLabel(stamp.label)
    }
}

struct PrimaryButton: View {
    let title: String
    var busy = false
    var enabled = true
    var command = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(TypeScale.bodyStrong)
                    .opacity(busy ? 0 : 1)
                if busy {
                    ProgressView()
                        .tint(FieldTheme.textOnAccent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(FieldTheme.textOnAccent)
            .background(enabled ? (command ? CommandTheme.accentFill : FieldTheme.accent) : FieldTheme.textMuted)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .disabled(!enabled || busy)
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct GhostButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypeScale.bodyStrong)
                .foregroundStyle(enabled ? FieldTheme.accent : FieldTheme.textMuted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(FieldTheme.strong, lineWidth: 1)
                )
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }
}

struct FormField: View {
    let label: String
    var keyboard: UIKeyboardType = .default
    var mono = false
    var error: String?
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TypeScale.label)
                .tracking(0.13)
                .foregroundStyle(FieldTheme.textSecondary)
            TextField("", text: $text)
                .font(mono ? TypeScale.numeric : TypeScale.body)
                .foregroundStyle(FieldTheme.textPrimary)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(FieldTheme.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(error == nil ? FieldTheme.strong : FieldTheme.alert, lineWidth: 1)
                )
                .environment(\.layoutDirection, mono ? .leftToRight : .rightToLeft)
            if let error {
                Text(error)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
            }
        }
    }
}

struct FormArea: View {
    let label: String
    var minHeight: CGFloat = 120
    var error: String?
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TypeScale.label)
                .tracking(0.13)
                .foregroundStyle(FieldTheme.textSecondary)
            TextEditor(text: $text)
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.textPrimary)
                .frame(minHeight: minHeight)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(FieldTheme.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(error == nil ? FieldTheme.strong : FieldTheme.alert, lineWidth: 1)
                )
            if let error {
                Text(error)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
            }
        }
    }
}

struct LedgerRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(TypeScale.label)
                .foregroundStyle(FieldTheme.textSecondary)
            Spacer(minLength: 12)
            Text(value.isEmpty ? "—" : value)
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(FieldTheme.hairline).frame(height: 1)
        }
    }
}

struct EmptyState: View {
    let title: String
    var caption: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 28))
                .foregroundStyle(FieldTheme.textMuted)
            Text(title)
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.textPrimary)
                .multilineTextAlignment(.center)
            if let caption {
                Text(caption)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                GhostButton(title: actionTitle, action: action)
                    .frame(maxWidth: 240)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct ToastBanner: View {
    let text: String
    var tone: StampTone = .done

    var body: some View {
        Text(text)
            .font(TypeScale.body)
            .foregroundStyle(FieldTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(FieldTheme.raised)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(FieldTheme.hairline, lineWidth: 1)
            )
            .overlay(alignment: .top) {
                Rectangle().fill(tone.ink).frame(height: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: Color(hex: 0x0F1B2D).opacity(0.16), radius: 12, y: 8)
    }
}
