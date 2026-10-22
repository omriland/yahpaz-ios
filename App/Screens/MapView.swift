import MapKit
import SwiftUI
import YahpazDomain

/// The ops מפה tab. Android draws it with Google Maps; iOS has no Google key, so the
/// tiles, pins and police polygons are MapKit and address search is Apple Maps.
/// Every rule (who shows, clustering, label zoom, mile posts, live pins) comes from `OpsMap`.
struct MapView: View {
    @EnvironmentObject private var app: AppModel
    @StateObject private var search = AddressSearch()

    @State private var pins: [YahpazDomain.MapPin] = []
    @State private var livePins: [LiveMapPin] = []
    @State private var milePosts: [MilePost] = []
    @State private var policeStations: [MKPolygon] = []
    @State private var loading = true
    @State private var loadFailed = false
    @State private var layers = OpsMapLayers()
    @State private var layersOpen = false
    @State private var query = ""
    @State private var searchOrigin: CLLocationCoordinate2D?
    @State private var nearby: [NearbyResponder] = []
    @State private var placesError: String?
    @State private var bbox = ISRAEL_VIEW_BBOX
    @State private var zoom = ISRAEL_MAP_ZOOM
    @State private var mapWidth: CGFloat = 390
    @State private var focusedPinId: String?
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: ISRAEL_MAP_LAT, longitude: ISRAEL_MAP_LNG),
        span: MKCoordinateSpan(latitudeDelta: 4.2, longitudeDelta: 3.2)
    ))

    private var manages: Bool { managesUnit(app.roles) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ZStack(alignment: .topLeading) {
                mapContent
                if !loading && !(loadFailed && pins.isEmpty) {
                    VStack(alignment: .leading, spacing: 8) {
                        Button { layersOpen = true } label: {
                            Image(systemName: "square.3.layers.3d")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(FieldTheme.accent)
                                .frame(width: 44, height: 44)
                                .background(FieldTheme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(MAP_LAYERS_TITLE)
                        MapLegend()
                    }
                    .padding(12)
                }
            }
            if searchOrigin != nil {
                nearbyPanel
            }
        }
        .background(FieldTheme.page.ignoresSafeArea())
        .sheet(isPresented: $layersOpen) {
            layersSheet
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he"))
        }
        .task { await load() }
        .task(id: manages) { await pollLivePins() }
        .onChange(of: query) { _, next in
            placesError = nil
            if next.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                clearSearch()
            } else {
                search.update(next)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(MAP_TITLE)
                .font(TypeScale.title)
                .foregroundStyle(FieldTheme.textPrimary)
            Text(MAP_CAPTION)
                .font(TypeScale.caption)
                .foregroundStyle(FieldTheme.textMuted)
            FormField(label: "חיפוש", placeholder: MAP_SEARCH_PLACEHOLDER, text: $query)
            if let placesError {
                Text(placesError)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.alert)
            }
            if !search.results.isEmpty && searchOrigin == nil {
                FieldCard {
                    ForEach(Array(search.results.prefix(6).enumerated()), id: \.offset) { index, result in
                        Button { choose(result) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(TypeScale.body)
                                    .foregroundStyle(FieldTheme.textPrimary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(TypeScale.caption)
                                        .foregroundStyle(FieldTheme.textMuted)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < min(search.results.count, 6) - 1 {
                            Rectangle().fill(FieldTheme.hairline).frame(height: 1)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var mapContent: some View {
        if loading {
            ProgressView()
                .tint(FieldTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if loadFailed && pins.isEmpty {
            EmptyState(title: MAP_LOAD_FAILED, actionTitle: "רענון") {
                Task { await load() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { proxy in
                map
                    .onAppear { mapWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in mapWidth = width }
            }
        }
    }

    private var map: some View {
        let catalog = catalogViewForViewport(pins, bbox: bbox, zoom: zoom)
        let showLabels = shouldShowMapPinLabels(zoom: zoom)
        let milesInView = milePostsInView(milePosts, bbox: bbox)
        let showMiles = shouldShowMilePosts(layerOn: layers.milePosts, zoom: zoom, inViewCount: milesInView.count)
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let padded = padBbox(bbox)
        let live = freshLivePins(livePins, nowMs: nowMs).filter { pointInBbox(lat: $0.lat, lng: $0.lng, bbox: padded) }
        return Map(position: $position) {
            if layers.policeStations {
                ForEach(Array(policeStations.enumerated()), id: \.offset) { _, polygon in
                    MapPolygon(polygon)
                        .foregroundStyle(FieldTheme.accent.opacity(0.16))
                        .stroke(FieldTheme.accent, lineWidth: 2)
                }
            }
            if showMiles {
                ForEach(Array(milesInView.enumerated()), id: \.offset) { _, post in
                    Annotation(milePostTooltip(post), coordinate: coordinate(post.lat, post.lng)) {
                        PinDisc(fill: FieldTheme.partial, label: zoom >= MILE_POST_DENSE_ZOOM ? "\(post.km)" : nil, small: true)
                    }
                    .annotationTitles(.hidden)
                }
            }
            ForEach(catalog.points) { pin in
                let chrome = mapUserPinChrome(pin)
                Annotation(pin.label, coordinate: coordinate(pin.lat, pin.lng)) {
                    PinDisc(
                        fill: chrome.unavailable || chrome.tone == .phone ? FieldTheme.draft : FieldTheme.done,
                        label: showLabels ? mapResponderPinLabel(callsign: pin.callsign, fullName: pin.fullName) : nil,
                        phone: chrome.tone == .phone,
                        focused: focusedPinId == pin.id
                    )
                    .accessibilityLabel("\(pin.label). \(chrome.tooltip)")
                }
                .annotationTitles(.hidden)
            }
            ForEach(catalog.clusters) { cluster in
                Annotation("\(cluster.count)", coordinate: coordinate(cluster.lat, cluster.lng)) {
                    Button { zoomInto(cluster) } label: {
                        Text("\(cluster.count)")
                            .font(TypeScale.stamp)
                            .foregroundStyle(FieldTheme.textOnAccent)
                            .frame(minWidth: 34, minHeight: 34)
                            .background(FieldTheme.accent, in: Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(cluster.count) מתנדבים")
                }
                .annotationTitles(.hidden)
            }
            if let searchOrigin {
                Annotation("חיפוש", coordinate: searchOrigin) {
                    PinDisc(fill: Color(red: 0.48, green: 0.37, blue: 0.65), label: showLabels ? "חיפוש" : nil)
                }
                .annotationTitles(.hidden)
            }
            ForEach(live) { pin in
                Annotation(pin.label, coordinate: coordinate(pin.lat, pin.lng)) {
                    PinDisc(fill: FieldTheme.done, label: showLabels ? pin.label : nil)
                        .accessibilityLabel("\(pin.label). \(pin.tooltip)")
                }
                .annotationTitles(.hidden)
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            let region = context.region
            bbox = LatLngBbox(
                south: region.center.latitude - region.span.latitudeDelta / 2,
                west: region.center.longitude - region.span.longitudeDelta / 2,
                north: region.center.latitude + region.span.latitudeDelta / 2,
                east: region.center.longitude + region.span.longitudeDelta / 2
            )
            zoom = webMercatorZoom(longitudeDelta: region.span.longitudeDelta, widthPoints: mapWidth)
        }
    }

    private var nearbyPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(MAP_NEARBY_TITLE)
                    .font(TypeScale.section)
                    .foregroundStyle(FieldTheme.textPrimary)
                Spacer()
                Button("נקה") {
                    query = ""
                    clearSearch()
                }
                .font(TypeScale.body)
                .foregroundStyle(FieldTheme.accent)
                .frame(minHeight: 44)
            }
            if nearby.isEmpty {
                Text(MAP_NEARBY_EMPTY)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textMuted)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(nearby) { row in
                            Button { focus(row) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(row.callsign) · \(row.name) · \(formatMapDistanceKm(row.km))")
                                        .font(TypeScale.body)
                                        .foregroundStyle(FieldTheme.textPrimary)
                                    Text(row.formattedAddress)
                                        .font(TypeScale.caption)
                                        .foregroundStyle(FieldTheme.textMuted)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
        .padding(12)
        .background(FieldTheme.raised)
        .overlay(alignment: .top) { Rectangle().fill(FieldTheme.hairline).frame(height: 1) }
    }

    private var layersSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(MAP_LAYERS_TITLE)
                .font(TypeScale.title)
                .foregroundStyle(FieldTheme.textPrimary)
            Toggle(MAP_LAYER_POLICE, isOn: $layers.policeStations)
                .font(TypeScale.body)
                .tint(FieldTheme.accent)
                .frame(minHeight: 44)
            Toggle(MAP_LAYER_MILE_POSTS, isOn: $layers.milePosts)
                .font(TypeScale.body)
                .tint(FieldTheme.accent)
                .frame(minHeight: 44)
            GhostButton(title: "סגירה") { layersOpen = false }
        }
        .padding(20)
        .background(FieldTheme.page.ignoresSafeArea())
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
    }

    private func coordinate(_ lat: Double, _ lng: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private func load() async {
        loading = true
        loadFailed = false
        do {
            pins = try await YahpazAPI.shared.fetchUnitMapPins()
        } catch {
            loadFailed = true
        }
        let assets = await MapAssets.shared.load()
        milePosts = assets.milePosts
        policeStations = assets.policeStations
        loading = false
    }

    private func pollLivePins() async {
        guard manages else {
            livePins = []
            return
        }
        while !Task.isCancelled {
            if let rows = try? await YahpazAPI.shared.fetchLiveMapPins() {
                livePins = rows
            }
            try? await Task.sleep(nanoseconds: UInt64(LIVE_MAP_POLL_MS) * 1_000_000)
        }
    }

    private func choose(_ result: MKLocalSearchCompletion) {
        Task {
            guard let place = await search.coordinate(for: result) else {
                placesError = MAP_PLACES_ONLY_ERROR
                return
            }
            query = result.title
            search.clear()
            YahpazKeyboard.dismiss()
            searchOrigin = place
            nearby = nearbyResponders(pins, originLat: place.latitude, originLng: place.longitude)
            let bounds = mapBoundsForRadiusKm(lat: place.latitude, lng: place.longitude, radiusKm: SEARCH_VIEW_RADIUS_KM)
            withAnimation {
                position = .region(MKCoordinateRegion(
                    center: place,
                    span: MKCoordinateSpan(latitudeDelta: bounds.north - bounds.south, longitudeDelta: bounds.east - bounds.west)
                ))
            }
        }
    }

    private func clearSearch() {
        search.clear()
        searchOrigin = nil
        nearby = []
        focusedPinId = nil
    }

    private func focus(_ row: NearbyResponder) {
        focusedPinId = "\(row.userId):\(row.kind.rawValue):\(row.lat):\(row.lng)"
        withAnimation {
            position = .camera(MapCamera(
                centerCoordinate: coordinate(row.lat, row.lng),
                distance: cameraDistance(forZoom: 14)
            ))
        }
    }

    private func zoomInto(_ cluster: CatalogCluster) {
        withAnimation {
            position = .camera(MapCamera(
                centerCoordinate: coordinate(cluster.lat, cluster.lng),
                distance: cameraDistance(forZoom: zoomAfterCatalogClusterClick(zoom))
            ))
        }
    }

    /// Camera altitude that shows roughly the same span as a Google zoom level on this map width.
    private func cameraDistance(forZoom target: Double) -> CLLocationDistance {
        let longitudeDelta = Double(mapWidth) * 360 / (256 * pow(2, target))
        return longitudeDelta * 111_320 * 1.6
    }
}

/// Google-style zoom for the visible span, so the `OpsMap` thresholds (10, 12, 14, 15) mean the same on iOS.
private func webMercatorZoom(longitudeDelta: Double, widthPoints: CGFloat) -> Double {
    guard longitudeDelta > 0, widthPoints > 0 else { return ISRAEL_MAP_ZOOM }
    return log2(Double(widthPoints) * 360 / (256 * longitudeDelta))
}

private struct PinDisc: View {
    let fill: Color
    var label: String?
    var phone = false
    var focused = false
    var small = false

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(fill)
                    .frame(width: small ? 10 : 16, height: small ? 10 : 16)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                if phone {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(Color.white)
                }
            }
            .scaleEffect(focused ? 1.4 : 1)
            if let label {
                Text(label)
                    .font(TypeScale.caption)
                    .foregroundStyle(FieldTheme.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(FieldTheme.raised.opacity(0.95), in: Capsule())
                    .fixedSize()
            }
        }
    }
}

private struct MapLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row(FieldTheme.done, MAP_LEGEND_ACTIVE)
            row(FieldTheme.draft, MAP_LEGEND_PHONE, phone: true)
            row(FieldTheme.draft, MAP_LEGEND_UNAVAILABLE)
        }
        .padding(10)
        .background(FieldTheme.raised.opacity(0.95), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func row(_ color: Color, _ label: String, phone: Bool = false) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(color).frame(width: 12, height: 12)
                if phone {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(Color.white)
                }
            }
            Text(label)
                .font(TypeScale.caption)
                .foregroundStyle(FieldTheme.textSecondary)
                .lineLimit(1)
        }
    }
}

/// Apple Maps address autocomplete scoped to Israel.
@MainActor
private final class AddressSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: ISRAEL_MAP_LAT, longitude: ISRAEL_MAP_LNG),
            span: MKCoordinateSpan(latitudeDelta: 4.2, longitudeDelta: 3.2)
        )
    }

    func update(_ query: String) {
        completer.queryFragment = query
    }

    func clear() {
        completer.cancel()
        results = []
    }

    func coordinate(for completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request(completion: completion)
        request.region = completer.region
        return try? await MKLocalSearch(request: request).start().mapItems.first?.placemark.coordinate
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let next = completer.results
        Task { @MainActor in self.results = next }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.results = [] }
    }
}

/// Bundled layers, parsed once off the main thread.
private actor MapAssets {
    static let shared = MapAssets()
    private var cached: (milePosts: [MilePost], policeStations: [MKPolygon])?

    func load() -> (milePosts: [MilePost], policeStations: [MKPolygon]) {
        if let cached { return cached }
        var posts: [MilePost] = []
        if let url = Bundle.main.url(forResource: "mile-posts", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([MilePost].self, from: data)
        {
            posts = decoded
                .map { MilePost(road: $0.road.trimmingCharacters(in: .whitespacesAndNewlines), km: $0.km, lat: $0.lat, lng: $0.lng) }
                .filter { !$0.road.isEmpty && $0.km >= 1 }
        }
        var polygons: [MKPolygon] = []
        if let url = Bundle.main.url(forResource: "police-station-boundaries", withExtension: "geojson"),
           let data = try? Data(contentsOf: url),
           let objects = try? MKGeoJSONDecoder().decode(data)
        {
            for case let feature as MKGeoJSONFeature in objects {
                for geometry in feature.geometry {
                    if let polygon = geometry as? MKPolygon {
                        polygons.append(polygon)
                    } else if let multi = geometry as? MKMultiPolygon {
                        polygons.append(contentsOf: multi.polygons)
                    }
                }
            }
        }
        let result = (posts, polygons)
        cached = result
        return result
    }
}
