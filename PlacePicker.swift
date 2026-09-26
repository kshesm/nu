import SwiftUI
import MapKit
import CoreLocation

@MainActor final class AddressLookup: ObservableObject {
    @Published var text = ""
    @Published var loading = false
    private let geocoder = CLGeocoder()
    private var generation = UUID()
    func resolve(_ point: Point) async {
        let token = UUID(); generation = token
        geocoder.cancelGeocode(); loading = true; text = ""
        do {
            try await Task.sleep(for: .milliseconds(400))
            try Task.checkCancellation()
            let places = try await geocoder.reverseGeocodeLocation(CLLocation(latitude: point.lat, longitude: point.lng), preferredLocale: Locale(identifier: "ru_RU"))
            guard generation == token, !Task.isCancelled else { return }
            if let p = places.first {
                let street = [p.thoroughfare, p.subThoroughfare].compactMap { $0 }.joined(separator: " ")
                text = [p.locality, street.isEmpty ? p.name : street].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            }
            loading = false
        } catch {
            guard generation == token else { return }
            loading = false
        }
    }
}
struct RadiusPicker: View {
    @Binding var point: Point
    @Binding var radius: Double
    @Binding var area: [Point]
    @Binding var address: String
    var lost: Bool
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.dismiss) var dismiss
    @StateObject private var lookup = AddressLookup()
    @State private var camera: MapCameraPosition = .automatic
    @State private var navigate = false
    @State private var trace: [Point] = []
    @State private var warning: String?
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MapReader { proxy in
                    ZStack {
                        Map(position: $camera, interactionModes: navigate ? .all : []) {
                            if area.count >= 3 {
                                MapPolygon(coordinates: area.map(\.coordinate)).foregroundStyle(theme.selected.accent.opacity(0.2)).stroke(theme.selected.accent, lineWidth: 2)
                            } else if lost {
                                MapCircle(center: point.coordinate, radius: radius).foregroundStyle(theme.selected.accent.opacity(0.2)).stroke(theme.selected.accent, lineWidth: 2)
                            }
                            if trace.count > 1 { MapPolyline(coordinates: trace.map(\.coordinate)).stroke(theme.selected.secondary, lineWidth: 3) }
                            Marker("Место", coordinate: point.coordinate).tint(theme.selected.accent)
                        }.mapStyle(theme.mapStyle)
                        if !navigate {
                            Color.clear.contentShape(Rectangle())
                                .onTapGesture { position in
                                    guard let c = proxy.convert(position, from: .local) else { return }
                                    withAnimation(.easeOut(duration: 0.2)) { point = Point(c); area = []; trace = []; warning = nil }
                                }
                                .gesture(DragGesture(minimumDistance: 12, coordinateSpace: .local)
                                    .onChanged { value in
                                        if trace.isEmpty, let c = proxy.convert(value.startLocation, from: .local) { trace.append(Point(c)) }
                                        if let c = proxy.convert(value.location, from: .local), trace.count < 500 { trace.append(Point(c)) }
                                    }
                                    .onEnded { _ in
                                        let selected = trace; trace = []
                                        guard selected.count >= 3 else { warning = "Обведите область чуть шире."; return }
                                        let lat = selected.map(\.lat), lng = selected.map(\.lng)
                                        guard (lat.max()! - lat.min()!) > 0.00008, (lng.max()! - lng.min()!) > 0.00008 else { warning = "Обведите замкнутую область, а не линию."; return }
                                        withAnimation(.easeOut(duration: 0.25)) { area = selected; point = Point(lat.reduce(0,+) / Double(lat.count), lng.reduce(0,+) / Double(lng.count)); warning = nil }
                                    })
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 13) {
                    Toggle("Перемещать и приближать карту", isOn: $navigate)
                    Text(navigate ? "Найдите нужную местность, затем выключите перемещение." : "Нажмите — выбрать точку. Проведите пальцем — обвести область.").font(.caption).foregroundStyle(.secondary)
                    if lookup.loading { ProgressView("Определяем адрес…") }
                    else { Label(lookup.text.isEmpty ? "Адрес недоступен · координаты сохранены" : lookup.text, systemImage: "mappin.and.ellipse").font(.subheadline) }
                    Text("\(point.lat, specifier: "%.5f"), \(point.lng, specifier: "%.5f")").font(.caption2).foregroundStyle(.secondary)
                    if let warning { Text(warning).font(.caption).foregroundStyle(.orange) }
                    if !area.isEmpty { Button("Сбросить область, оставить точку") { area = [] } }
                    if lost && area.isEmpty {
                        HStack { Text("Радиус поиска"); Spacer(); Text("\(Int(radius)) м").monospacedDigit() }
                        Slider(value: $radius.animation(.easeOut(duration: 0.18)), in: 50...2000, step: 50)
                    }
                    ActionButton(title: area.isEmpty ? "Выбрать это место" : "Выбрать эту область", symbol: "checkmark") {
                        address = lookup.text; dismiss()
                    }.disabled(lookup.loading || !trace.isEmpty)
                }.padding(18).background(theme.selected.surface)
            }.navigationTitle("Место и область").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { dismiss() } } }
                .onAppear { camera = .region(MKCoordinateRegion(center: point.coordinate, latitudinalMeters: 3500, longitudinalMeters: 3500)) }
                .task(id: point) { await lookup.resolve(point) }
                .onChange(of: lookup.text) { _, value in address = value }
        }
    }
}
