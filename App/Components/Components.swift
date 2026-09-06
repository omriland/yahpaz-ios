import SwiftUI
import UIKit
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

struct StampWithNote: View {
    let stamp: StampDescriptor
    var note: String? = nil

    var body: some View {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            StampChip(stamp: stamp)
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                StampChip(stamp: stamp)
                Text(trimmed)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 176, alignment: .trailing)
            }
        }
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
    var danger = false
    let action: () -> Void

    var body: some View {
        let color: Color = {
            if !enabled { return FieldTheme.textMuted }
            return danger ? FieldTheme.alert : FieldTheme.accent
        }()
        Button(action: action) {
            Text(title)
                .font(TypeScale.bodyStrong)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(danger ? FieldTheme.alert : FieldTheme.strong, lineWidth: 1)
                )
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }
}

enum YahpazKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// No-op. `ToolbarItemGroup(placement: .keyboard)` renders as a capsule floating well
    /// above the keyboard, overlapping form fields and swallowing taps meant for them, and
    /// it outlives the keyboard it belongs to. Dismissal is covered by `yahpazFormScroll`
    /// (drag to dismiss) and by tapping outside the field.
    func yahpazKeyboardAccessory() -> some View {
        self
    }

    func yahpazFormScroll() -> some View {
        scrollDismissesKeyboard(.interactively)
    }

    func yahpazRootNavigationBarHidden() -> some View {
        toolbar(.hidden, for: .navigationBar)
    }
}

struct FormField: View {
    let label: String
    var keyboard: UIKeyboardType = .default
    var mono = false
    var ltr = false
    var error: String?
    var enabled = true
    var placeholder: String? = nil
    var submit: UIReturnKeyType = .done
    var contentType: UITextContentType? = nil
    var onSubmit: (() -> Void)? = nil
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TypeScale.label)
                .tracking(0.13)
                .foregroundStyle(FieldTheme.textSecondary)
            YahpazTextField(
                text: $text,
                font: mono ? UIFontScale.numeric : UIFontScale.body,
                keyboard: keyboard,
                contentType: contentType,
                forceLeftToRight: mono || ltr,
                returnKey: submit,
                enabled: enabled,
                placeholder: placeholder,
                onSubmit: onSubmit
            )
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 12)
                .background(FieldTheme.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(error == nil ? FieldTheme.strong : FieldTheme.alert, lineWidth: 1)
                )
                .opacity(enabled ? 1 : 0.55)
            if let error {
                Text(error)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
            }
        }
    }
}

/// SwiftUI's `TextField` does not paint its text while it is first responder anywhere in
/// this app — the binding updates and every unfocused view of the same value renders, but
/// the focused field stays blank until it resigns. A `UITextField` in the same chrome does
/// not have the problem, so every text input goes through UIKit.
struct YahpazTextField: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var isSecure = false
    var forceLeftToRight = false
    var returnKey: UIReturnKeyType = .done
    var enabled = true
    var placeholder: String? = nil
    var onSubmit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartInsertDeleteType = .no
        field.tintColor = UIColor(FieldTheme.pending)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.font = font
        field.keyboardType = keyboard
        field.textContentType = contentType
        field.isSecureTextEntry = isSecure
        field.returnKeyType = returnKey
        field.isEnabled = enabled
        field.textColor = UIColor(enabled ? FieldTheme.textPrimary : FieldTheme.textMuted)
        field.semanticContentAttribute = forceLeftToRight ? .forceLeftToRight : .forceRightToLeft
        field.textAlignment = forceLeftToRight ? .left : .right
        field.attributedPlaceholder = placeholder.map {
            NSAttributedString(
                string: $0,
                attributes: [
                    .foregroundColor: UIColor(FieldTheme.textMuted),
                    .font: font,
                ]
            )
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: YahpazTextField

        init(_ parent: YahpazTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.onSubmit?()
            return true
        }
    }
}

struct SecureFormField: View {
    let label: String
    var error: String? = nil
    var contentType: UITextContentType = .password
    var submit: UIReturnKeyType = .done
    var onSubmit: (() -> Void)? = nil
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TypeScale.label)
                .tracking(0.13)
                .foregroundStyle(FieldTheme.textSecondary)
            YahpazTextField(
                text: $text,
                font: UIFontScale.body,
                contentType: contentType,
                isSecure: true,
                forceLeftToRight: true,
                returnKey: submit,
                onSubmit: onSubmit
            )
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 12)
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

struct ReturnDateField: View {
    let label: String
    var error: String? = nil
    var enabled = true
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TypeScale.label)
                .tracking(0.13)
                .foregroundStyle(FieldTheme.textSecondary)
            ReturnDateTextField(text: $text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 12)
                .background(FieldTheme.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(error == nil ? FieldTheme.strong : FieldTheme.alert, lineWidth: 1)
                )
                .environment(\.layoutDirection, .leftToRight)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.55)
            if let error {
                Text(error)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
            }
        }
    }
}

private struct ReturnDateTextField: UIViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.keyboardType = .numberPad
        field.textAlignment = .left
        field.semanticContentAttribute = .forceLeftToRight
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartInsertDeleteType = .no
        field.font = UIFont(name: "IBM Plex Mono", size: 16)
            ?? .monospacedSystemFont(ofSize: 16, weight: .regular)
        field.textColor = UIColor(red: 15 / 255, green: 27 / 255, blue: 45 / 255, alpha: 1)
        field.attributedPlaceholder = NSAttributedString(
            string: "30/12/2026",
            attributes: [
                .foregroundColor: UIColor(red: 91 / 255, green: 111 / 255, blue: 134 / 255, alpha: 1),
                .font: field.font as Any,
            ]
        )
        field.text = text
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
            context.coordinator.moveCaretToEnd(uiView)
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        /// A full date already holds the 8-digit maximum, so every further keystroke is a
        /// silent no-op. Selecting on focus lets the first digit start a new date.
        func textFieldDidBeginEditing(_ textField: UITextField) {
            if digitsOnly(textField.text ?? "").count >= 8 {
                textField.selectAll(nil)
            }
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let current = textField.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return false }
            let incoming = current.replacingCharacters(in: swiftRange, with: string)
            let formatted = applyReturnDateKeystroke(previous: current, incoming: incoming)
            textField.text = formatted
            text.wrappedValue = formatted
            moveCaretToEnd(textField)
            return false
        }

        func moveCaretToEnd(_ textField: UITextField) {
            let end = textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: end, to: end)
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

struct FormCheckbox: View {
    let label: String
    var checked: Bool
    var enabled = true
    let onChange: (Bool) -> Void

    var body: some View {
        Button {
            if enabled { onChange(!checked) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(enabled ? FieldTheme.accent : FieldTheme.textMuted)
                    .font(.system(size: 20))
                Text(label)
                    .font(TypeScale.body)
                    .foregroundStyle(enabled ? FieldTheme.textPrimary : FieldTheme.textMuted)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityAddTraits(checked ? [.isSelected] : [])
    }
}

struct TimeField: View {
    let label: String
    var placeholder: String = "08:00"
    @Binding var text: String
    var onFourDigitsComplete: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TypeScale.label)
                .foregroundStyle(FieldTheme.textSecondary)
            TextField("", text: Binding(
                get: { text },
                set: { incoming in
                    let next = applyTimeKeystroke(previous: text, incoming: incoming)
                    let advanced = digitsOnly(text).count < 4 && digitsOnly(next).count == 4
                    text = next
                    if advanced { onFourDigitsComplete?() }
                }
            ), prompt: Text(placeholder))
                .font(TypeScale.numeric)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(FieldTheme.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(FieldTheme.strong, lineWidth: 1)
                )
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}

struct FrozenEventMark: View {
    let flags: EventFreezeFlags

    var body: some View {
        if let tip = flags.tooltipHe {
            Image(systemName: "snowflake")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FieldTheme.pending)
                .accessibilityLabel(tip)
        }
    }
}

struct EventDeleteControls: View {
    var visible: Bool
    var confirmArmed: Bool
    var hint: String?
    var deleting: Bool
    let onClick: () -> Void

    var body: some View {
        if visible {
            VStack(alignment: .leading, spacing: 8) {
                if let hint {
                    Text(hint)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.alert)
                }
                GhostButton(
                    title: confirmArmed ? EVENT_DELETE_ACTION : EVENT_DELETE_TITLE,
                    enabled: !deleting,
                    danger: true,
                    action: onClick
                )
            }
        }
    }
}

struct FieldCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldTheme.raised)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FieldTheme.hairline, lineWidth: 1)
        )
    }
}

struct PrivacyPolicyLink: View {
    var command = false
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            Text("מדיניות פרטיות")
                .font(TypeScale.caption)
                .foregroundStyle(command ? CommandTheme.textSecondary : FieldTheme.textMuted)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("מדיניות פרטיות")
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
