import SwiftUI
import YahpazDomain

struct PrimaryCreateFab: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypeScale.bodyStrong)
                .foregroundStyle(FieldTheme.textOnAccent)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(FieldTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct ToolsBackRow: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.backward")
                    Text("חזרה")
                }
                .font(TypeScale.bodyStrong)
                .foregroundStyle(FieldTheme.accent)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("חזרה")
            Text(title)
                .font(TypeScale.title)
                .foregroundStyle(FieldTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

struct OptionRowSelector: View {
    let label: String
    let options: [(String, String)]
    let selected: String
    var enabled = true
    var error: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TypeScale.label)
                .foregroundStyle(FieldTheme.textSecondary)
            FieldCard {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button {
                        if enabled { onSelect(option.0) }
                    } label: {
                        HStack {
                            Text(option.1)
                                .font(option.0 == selected ? TypeScale.bodyStrong : TypeScale.body)
                                .foregroundStyle(enabled ? FieldTheme.textPrimary : FieldTheme.textMuted)
                            Spacer(minLength: 8)
                            if option.0 == selected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(FieldTheme.accent)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                    if index < options.count - 1 {
                        Rectangle()
                            .fill(FieldTheme.hairline)
                            .frame(height: 1)
                    }
                }
            }
            if let error {
                Text(error)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
            }
        }
    }
}

struct LookupPickerField: View {
    let label: String
    let options: [LookupOption]
    let selectedId: String
    var placeholder: String
    var searchPlaceholder: String
    var error: String?
    var enabled = true
    var allowClear = false
    let onSelect: (String) -> Void

    @State private var open = false
    @State private var query = ""

    private var selectedName: String {
        options.first(where: { $0.id == selectedId })?.name ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TypeScale.label)
                .foregroundStyle(FieldTheme.textSecondary)
            Button {
                if enabled {
                    query = ""
                    open = true
                }
            } label: {
                HStack {
                    Text(selectedName.isEmpty ? placeholder : selectedName)
                        .font(TypeScale.body)
                        .foregroundStyle(selectedName.isEmpty ? FieldTheme.textMuted : FieldTheme.textPrimary)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(FieldTheme.accent)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(FieldTheme.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(error == nil ? FieldTheme.strong : FieldTheme.alert, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            if let error {
                Text(error)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
            }
        }
        .sheet(isPresented: $open) {
            lookupSheet
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he"))
        }
    }

    private var visible: [LookupOption] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return options }
        return options.filter { textIncludesQuery($0.name, query: trimmed) }
    }

    private var lookupSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(TypeScale.section)
                .foregroundStyle(FieldTheme.textPrimary)
            FormField(label: "חיפוש", placeholder: searchPlaceholder, text: $query)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if visible.isEmpty {
                        Text("לא נמצאו פריטים תואמים")
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.textMuted)
                            .padding(.vertical, 16)
                    }
                    if allowClear {
                        Button {
                            onSelect("")
                            open = false
                        } label: {
                            HStack {
                                Text("ללא")
                                    .font(selectedId.isEmpty ? TypeScale.bodyStrong : TypeScale.body)
                                    .foregroundStyle(FieldTheme.textPrimary)
                                Spacer(minLength: 8)
                                if selectedId.isEmpty {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(FieldTheme.accent)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(visible) { option in
                        Button {
                            onSelect(option.id)
                            open = false
                        } label: {
                            HStack {
                                Text(option.name)
                                    .font(option.id == selectedId ? TypeScale.bodyStrong : TypeScale.body)
                                    .foregroundStyle(FieldTheme.textPrimary)
                                Spacer(minLength: 8)
                                if option.id == selectedId {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(FieldTheme.accent)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .background(FieldTheme.page.ignoresSafeArea())
        .yahpazFormScroll()
        .yahpazKeyboardAccessory()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct CrewAssignmentSection: View {
    let assignOpenLabel: String
    let assignCloseLabel: String
    let profiles: [AssignableProfile]
    let selectedIds: [String]
    var caption: String
    var emptyHint: String
    var emptyRoster: String
    var emptyQuery: String
    var error: String?
    var removeLabel: String = EVENT_ASSIGN_REMOVE
    var disabledIds: Set<String> = []
    var disabledHint: String = EVENT_SELF_ASSIGN_DISABLED_HINT
    var onResponderTap: ((String) -> Void)? = nil
    let onToggle: (String) -> Void

    @State private var open = false
    @State private var query = ""

    private var selectedPeople: [AssignableProfile] {
        selectedIds.map { id in
            profiles.first(where: { $0.id == id })
                ?? AssignableProfile(id: id, fullName: "מתנדב", callsign: "—")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(caption)
                .font(TypeScale.label)
                .foregroundStyle(FieldTheme.textSecondary)
            GhostButton(title: open ? assignCloseLabel : assignOpenLabel) {
                if open {
                    open = false
                } else {
                    query = ""
                    open = true
                }
            }
            if let error {
                Text(error)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
            }
            if selectedPeople.isEmpty {
                Text(emptyHint)
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textSecondary)
            } else {
                FieldCard {
                    ForEach(Array(selectedPeople.enumerated()), id: \.element.id) { index, person in
                        HStack {
                            Button {
                                if let onResponderTap {
                                    onResponderTap(person.id)
                                }
                            } label: {
                                Text(person.display)
                                    .font(TypeScale.body)
                                    .foregroundStyle(FieldTheme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(onResponderTap == nil)
                            Button {
                                onToggle(person.id)
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("הסרה")
                                        .font(TypeScale.caption)
                                }
                                .foregroundStyle(FieldTheme.alert)
                                .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(removeLabel)
                        }
                        .frame(minHeight: 44)
                        if index < selectedPeople.count - 1 {
                            Rectangle()
                                .fill(FieldTheme.hairline)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $open) {
            assignSheet
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he"))
        }
    }

    private var visible: [AssignableProfile] {
        filterAssignableProfiles(profiles.filter { !selectedIds.contains($0.id) }, query: query)
    }

    private var assignSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(assignOpenLabel)
                .font(TypeScale.section)
                .foregroundStyle(FieldTheme.textPrimary)
            FormField(label: "חיפוש", placeholder: "חיפוש לפי שם או או״ק", text: $query)
            Text(caption)
                .font(TypeScale.caption)
                .foregroundStyle(FieldTheme.textMuted)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if visible.isEmpty {
                        Text(profiles.isEmpty ? emptyRoster : emptyQuery)
                            .font(TypeScale.body)
                            .foregroundStyle(FieldTheme.textMuted)
                            .padding(.vertical, 16)
                    }
                    ForEach(visible) { profile in
                        let disabled = disabledIds.contains(profile.id)
                        Button {
                            if !disabled { onToggle(profile.id) }
                        } label: {
                            HStack {
                                Text(profile.display)
                                    .font(TypeScale.body)
                                    .foregroundStyle(disabled ? FieldTheme.textMuted : FieldTheme.textPrimary)
                                Spacer(minLength: 8)
                                Text(disabled ? disabledHint : "הוספה")
                                    .font(TypeScale.caption)
                                    .foregroundStyle(disabled ? FieldTheme.textMuted : FieldTheme.accent)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(disabled)
                    }
                }
            }
            GhostButton(title: assignCloseLabel) { open = false }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .background(FieldTheme.page.ignoresSafeArea())
        .yahpazFormScroll()
        .yahpazKeyboardAccessory()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
