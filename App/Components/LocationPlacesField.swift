import SwiftUI
import YahpazDomain

struct LocationPlacesField: View {
    let value: LocationPinFields
    var error: String? = nil
    var required = false
    var roadName: String? = nil
    var placeholder: String = EVENT_LOCATION_PLACEHOLDER
    let onChange: (LocationPinFields) -> Void
    var onJunctionCommit: ((HighwayJunction) -> Void)? = nil
    var onAutocompleteUnavailable: (() -> Void)? = nil

    @State private var query = ""
    @State private var open = false
    @State private var junctions: [HighwayJunction] = []
    @State private var predictions: [PlacePrediction] = []
    @State private var isSearching = false
    @State private var localSearchFailed = false
    @State private var sessionToken = GooglePlaces.newSessionToken()
    @State private var searchGeneration = 0
    @State private var warnedUnavailable = false
    @State private var suppressQueryEcho = false

    private var ranked: [RankedLocationSuggestion] {
        rankLocationSuggestions(
            junctions: junctions,
            predictions: predictions,
            freeText: query,
            allowFreeText: true
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("מיקום")
                .font(TypeScale.label)
                .tracking(0.13)
                .foregroundStyle(FieldTheme.textSecondary)
            VStack(alignment: .leading, spacing: 0) {
                YahpazTextField(
                    text: $query,
                    font: UIFontScale.body,
                    placeholder: placeholder,
                    onFocus: { open = true },
                    onBlur: { commitFreeTextIfNeeded() },
                    onSubmit: { selectFirstOrFreeText() }
                )
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 12)
                .onChange(of: query) { _, next in
                    if suppressQueryEcho {
                        suppressQueryEcho = false
                        return
                    }
                    open = true
                    onChange(
                        applyLocationFieldChange(
                            value,
                            next: LocationFieldChange(location: next)
                        )
                    )
                    scheduleSearch()
                }
                if open && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    suggestionList
                }
            }
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
        .onAppear {
            query = value.location
        }
        .onChange(of: value.location) { _, next in
            if next != query {
                suppressQueryEcho = true
                query = next
            }
        }
        .task {
            await YahpazAPI.shared.prefetchJunctionCatalog()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(required ? "מיקום, שדה חובה" : "מיקום")
    }

    @ViewBuilder
    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(FieldTheme.hairline)
                .frame(height: 1)
            if isSearching {
                Text(EVENT_LOCATION_SEARCHING)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if localSearchFailed {
                Text(EVENT_LOCATION_JUNCTIONS_UNAVAILABLE)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(Array(ranked.enumerated()), id: \.offset) { index, option in
                let previous = index > 0 ? ranked[index - 1] : nil
                if let group = groupLabel(for: option, previous: previous) {
                    Text(group)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                }
                Button {
                    select(option)
                } label: {
                    suggestionRow(option)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func suggestionRow(_ option: RankedLocationSuggestion) -> some View {
        switch option {
        case .junction(let junction):
            VStack(alignment: .leading, spacing: 2) {
                Text(junction.nameHe)
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textPrimary)
                if let roads = junction.roads, !roads.isEmpty {
                    Text("כביש \(roads)")
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                }
            }
        case .google(let prediction):
            VStack(alignment: .leading, spacing: 2) {
                Text(prediction.primaryText)
                    .font(TypeScale.body)
                    .foregroundStyle(FieldTheme.textPrimary)
                if !prediction.secondaryText.isEmpty {
                    Text(prediction.secondaryText)
                        .font(TypeScale.caption)
                        .foregroundStyle(FieldTheme.textMuted)
                }
            }
        case .freeText(let text):
            Text(freeTextLabel(text))
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.textSecondary)
        }
    }

    private func groupLabel(
        for option: RankedLocationSuggestion,
        previous: RankedLocationSuggestion?
    ) -> String? {
        switch option {
        case .freeText:
            return nil
        case .junction:
            if case .junction = previous { return nil }
            return EVENT_LOCATION_GROUP_JUNCTIONS
        case .google:
            if case .google = previous { return nil }
            return EVENT_LOCATION_GROUP_GOOGLE
        }
    }

    private func freeTextLabel(_ text: String) -> String {
        "שימוש ב־\"\(text)\" כפי שהוזן"
    }

    private func scheduleSearch() {
        searchGeneration += 1
        let generation = searchGeneration
        let localQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard open, !localQuery.isEmpty else {
            junctions = []
            predictions = []
            isSearching = false
            localSearchFailed = false
            return
        }
        guard let googleQuery = eventGeocodeQuery(road: roadName, location: localQuery) else { return }
        junctions = []
        predictions = []
        isSearching = true
        localSearchFailed = false
        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard generation == searchGeneration else { return }
            let result = await searchLocationSuggestionsCombined(
                localQuery: localQuery,
                googleQuery: googleQuery,
                sessionToken: sessionToken,
                searchJunctions: { try await YahpazAPI.shared.searchHighwayJunctions($0) },
                searchPlaces: { query, token in
                    await GooglePlaces.fetchPredictions(query: query, sessionToken: token)
                }
            )
            guard generation == searchGeneration else { return }
            localSearchFailed = result.localFailed
            junctions = result.junctions
            switch result.places {
            case .ok(let next):
                predictions = next
            case .failed:
                predictions = []
                notifyUnavailable()
            }
            isSearching = false
        }
    }

    private func select(_ option: RankedLocationSuggestion) {
        switch option {
        case .junction(let junction):
            commitJunction(junction)
        case .google(let prediction):
            Task { await commitGoogle(prediction) }
        case .freeText(let text):
            commitFreeText(text)
        }
    }

    private func selectFirstOrFreeText() {
        if let first = ranked.first {
            select(first)
        } else {
            commitFreeText(query)
        }
    }

    private func commitJunction(_ junction: HighwayJunction) {
        let location = junctionLocationLabel(junctionName: junction.nameHe, typedQuery: query)
        suppressQueryEcho = true
        query = location
        onChange(
            applyLocationFieldChange(
                value,
                next: LocationFieldChange(
                    location: location,
                    locationPlaceId: junctionPlaceId(junction.id),
                    locationLat: junction.lat,
                    locationLng: junction.lng
                )
            )
        )
        onJunctionCommit?(junction)
        sessionToken = GooglePlaces.newSessionToken()
        open = false
    }

    private func commitGoogle(_ prediction: PlacePrediction) async {
        if let details = await GooglePlaces.fetchDetails(placeId: prediction.placeId, sessionToken: sessionToken) {
            suppressQueryEcho = true
            query = details.label
            onChange(
                applyLocationFieldChange(
                    value,
                    next: LocationFieldChange(
                        location: details.label,
                        locationPlaceId: details.placeId,
                        locationLat: details.lat,
                        locationLng: details.lng
                    )
                )
            )
        } else {
            let fallback = [prediction.primaryText, prediction.secondaryText]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            commitFreeText(fallback.isEmpty ? query : fallback)
            notifyUnavailable()
            return
        }
        sessionToken = GooglePlaces.newSessionToken()
        open = false
    }

    private func commitFreeText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        suppressQueryEcho = true
        query = trimmed
        onChange(
            applyLocationFieldChange(
                value,
                next: LocationFieldChange(location: trimmed)
            )
        )
        sessionToken = GooglePlaces.newSessionToken()
        open = false
    }

    private func commitFreeTextIfNeeded() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            commitFreeText(trimmed)
        } else {
            open = false
        }
    }

    private func notifyUnavailable() {
        if warnedUnavailable { return }
        warnedUnavailable = true
        onAutocompleteUnavailable?()
    }
}
