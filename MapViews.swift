import SwiftUI
import MapKit

struct DistrictMenu: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        Menu {
            Button("Весь Минск") { store.selectedDistrict = "Весь Минск" }
            ForEach(District.all) { district in Button(district.name) { store.selectedDistrict = district.name } }
        } label: {
            Label(store.selectedDistrict, systemImage: "location.circle.fill")
                .font(.subheadline.bold()).lineLimit(1).padding(11).background(.regularMaterial, in: Capsule())
        }
    }
}
struct MapEntry: Identifiable {
    var id: String
    var title: String
    var point: Point
    var symbol: String
    var post: Post?
    var event: CityEvent?
}
struct MapGroup: Identifiable {
    var id: String
    var entries: [MapEntry]
    var point: Point {
        Point(entries.map { $0.point.lat }.reduce(0, +) / Double(entries.count),
              entries.map { $0.point.lng }.reduce(0, +) / Double(entries.count))
    }
}
struct NearbyView: View {
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var location: LocationService
    @EnvironmentObject var events: EventsStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(center: Point.minsk.coordinate, latitudinalMeters: 6500, longitudinalMeters: 6500))
    @State private var span = MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.1)
    @State private var mapSize = CGSize(width: 390, height: 650)
    @State private var heat = false
    @State private var categoriesOpen = false
    @State private var category: CommunityCategory?
    @State private var selectedPost: Post?
    @State private var selectedEvent: CityEvent?
    @State private var selectedGroup: MapGroup?
    @State private var create = false
    @State private var followUser = true
    @State private var resettingForLocation = false
    @State private var highlight = 1.0
    var district: District? { District.all.first { $0.name == store.selectedDistrict } }
    var posts: [Post] {
        store.data.posts.filter {
            !$0.completed && store.window.includes(start: $0.start, end: $0.endsAt, now: store.clock)
            && (category == nil || $0.category == category)
            && (district == nil || $0.district == district?.name)
        }
    }
    var ticketEvents: [CityEvent] {
        events.catalog.events.filter {
            $0.matches(store.window, now: store.clock)
            && (category == nil || category == .events)
            && (district == nil || $0.district == district?.name)
        }
    }
    var entries: [MapEntry] {
        let community = posts.map { MapEntry(id: $0.id.uuidString, title: $0.title, point: $0.point, symbol: $0.category.symbol, post: $0) }
        let tickets = ticketEvents.map { MapEntry(id: $0.url, title: $0.title, point: $0.point, symbol: "ticket.fill", event: $0) }
        return community + tickets
    }
    func groups(_ values: [MapEntry], heatMode: Bool = false) -> [MapGroup] {
        let latCell = heatMode ? 0.0027 : max(0.00001, span.latitudeDelta * 65 / max(1, mapSize.height))
        let lngCell = heatMode ? 0.0045 : max(0.00001, span.longitudeDelta * 65 / max(1, mapSize.width))
        let bins = Dictionary(grouping: values) { "\(Int(floor($0.point.lat / latCell))):\(Int(floor($0.point.lng / lngCell)))" }
        return bins.map { MapGroup(id: $0.key, entries: $0.value) }.sorted { $0.id < $1.id }
    }
    var density: [MapGroup] {
        groups(entries.filter { $0.event != nil || $0.post?.category == .events || $0.post?.category == .company }, heatMode: true)
    }
    func move(_ point: Point, meters: Double) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.9)) {
            camera = .region(MKCoordinateRegion(center: point.coordinate, latitudinalMeters: meters, longitudinalMeters: meters))
        }
    }
    func open(_ group: MapGroup) {
        if group.entries.count == 1, let entry = group.entries.first {
            selectedPost = entry.post; selectedEvent = entry.event
        } else if span.latitudeDelta > 0.008 {
            move(group.point, meters: max(450, span.latitudeDelta * 111000 * 0.38))
        } else { selectedGroup = group }
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                map
                controls
            }.onAppear { mapSize = geometry.size }
                .onChange(of: geometry.size) { _, size in mapSize = size }
        }.navigationBarTitleDisplayMode(.inline)
            .onChange(of: store.selectedDistrict) { _, _ in
                if resettingForLocation {
                    resettingForLocation = false
                    if let point = location.point { move(point, meters: 1800) }
                    return
                }
                followUser = false; highlight = 0.1
                move(district?.point ?? .minsk, meters: district == nil ? 19000 : 5500)
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.9)) { highlight = 1 }
            }
            .onChange(of: location.point) { _, point in if followUser, let point { move(point, meters: 1800) } }
            .sheet(item: $selectedPost) { PostDetail(postID: $0.id) }
            .sheet(item: $selectedEvent) { EventDetail(event: $0) }
            .sheet(item: $selectedGroup) { group in ClusterList(group: group) }
            .sheet(isPresented: $create) { CreatePostView() }
    }
    private var map: some View {
        Map(position: $camera) {
            if let point = location.point {
                Annotation("Вы здесь", coordinate: point.coordinate) {
                    ZStack { Circle().fill(.blue.opacity(0.18)).frame(width: 42, height: 42); Circle().fill(.blue).frame(width: 17, height: 17).overlay(Circle().stroke(.white, lineWidth: 3)) }.accessibilityLabel("Ваше местоположение")
                }
            }
            if let district {
                MapCircle(center: district.point.coordinate, radius: 1800 * highlight)
                    .foregroundStyle(theme.selected.secondary.opacity(0.07))
                    .stroke(theme.selected.secondary.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
            }
            if heat {
                ForEach(density) { group in
                    MapCircle(center: group.point.coordinate, radius: 600).foregroundStyle(theme.selected.secondary.opacity(0.1))
                    MapCircle(center: group.point.coordinate, radius: 350).foregroundStyle(theme.selected.secondary.opacity(0.22))
                    MapCircle(center: group.point.coordinate, radius: 180).foregroundStyle(theme.selected.accent.opacity(min(0.85, 0.2 + Double(group.entries.count) * 0.13)))
                    Annotation("События", coordinate: group.point.coordinate) { clusterButton(group) }
                }
            } else {
                ForEach(posts) { post in
                    if let area = post.area, area.count >= 3 {
                        MapPolygon(coordinates: area.map(\.coordinate)).foregroundStyle(theme.selected.accent.opacity(0.16)).stroke(theme.selected.accent, lineWidth: 2)
                    } else if post.searchRadius > 0 {
                        MapCircle(center: post.point.coordinate, radius: post.searchRadius).foregroundStyle(theme.selected.accent.opacity(0.16)).stroke(theme.selected.accent, lineWidth: 1.5)
                    }
                }
                ForEach(groups(entries)) { group in
                    Annotation(group.entries.count > 1 ? "\(group.entries.count) рядом" : group.entries[0].title, coordinate: group.point.coordinate) { clusterButton(group) }
                }
            }
        }.mapStyle(theme.mapStyle).mapControls { MapCompass() }
            .onMapCameraChange(frequency: .onEnd) { context in span = context.region.span }
    }
    private func clusterButton(_ group: MapGroup) -> some View {
        Button { open(group) } label: {
            ZStack(alignment: .topTrailing) {
                Group {
                    if group.entries.count > 1 || heat { Text("\(group.entries.count)").font(.title3.bold().monospacedDigit()) }
                    else { Image(systemName: group.entries[0].symbol).font(.headline) }
                }.foregroundStyle(theme.selected.dark ? Color.black : Color.white)
                    .frame(width: group.entries.count > 1 ? 52 : 43, height: group.entries.count > 1 ? 52 : 43)
                    .background(theme.selected.gradient, in: Circle()).shadow(color: .black.opacity(0.2), radius: 7, y: 3)
                if group.entries.contains(where: { $0.post?.saved == true || ($0.event.map { events.isSaved($0) } ?? false) }) {
                    Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow).shadow(color: .black, radius: 2)
                }
            }
        }.buttonStyle(.plain).accessibilityLabel(group.entries.count > 1 ? "\(group.entries.count) событий. Приблизить или открыть список" : group.entries[0].title)
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DistrictMenu()
                Spacer(minLength: 6)
                Button { heat.toggle() } label: { Label(heat ? "Метки" : "Тепло", systemImage: heat ? "mappin.and.ellipse" : "flame.fill").font(.subheadline.bold()).padding(11).background(.regularMaterial, in: Capsule()) }
                Button { withAnimation(.spring(response: 0.3)) { categoriesOpen.toggle() } } label: { Image(systemName: "line.3.horizontal.decrease").padding(12).background(category == nil ? theme.selected.surface : theme.selected.accent, in: Circle()) }.accessibilityLabel("Категории: " + (category?.rawValue ?? "Всё рядом"))
            }
            TimeBar()
            if categoriesOpen {
                VStack(alignment: .leading, spacing: 2) {
                    Button("Всё рядом") { choose(nil) }.padding(12)
                    ForEach(CommunityCategory.allCases) { value in Button { choose(value) } label: { Label(value.rawValue, systemImage: value.symbol).padding(12).frame(maxWidth: .infinity, alignment: .leading) } }
                }.frame(width: 200).padding(5).background(theme.selected.surface, in: RoundedRectangle(cornerRadius: 20)).shadow(radius: 8).transition(.move(edge: .trailing).combined(with: .opacity)).frame(maxWidth: .infinity, alignment: .trailing)
            }
            Spacer()
            if entries.isEmpty { Text("В этот период здесь пока нет событий").font(.caption).padding(10).background(.regularMaterial, in: Capsule()) }
            if let message = location.message { Text(message).font(.caption).padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    if heat { Text("Плотность событий · \(store.window.rawValue.lowercased())").font(.caption.bold()); Text("Меньше  🔵  🟣  🩷  Больше").font(.caption2) }
                    if district != nil { Text("Ориентир района, не граница").font(.caption2) }
                    if store.window == .now { Text("Для афиши без времени окончания: первые 2 часа после начала").font(.caption2) }
                }.padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)).opacity(heat || district != nil || store.window == .now ? 1 : 0)
                Spacer(minLength: 10)
                Button {
                    followUser = true; resettingForLocation = store.selectedDistrict != "Весь Минск"; store.selectedDistrict = "Весь Минск"
                    location.request()
                    if let point = location.point { move(point, meters: 1800) }
                } label: { Label("Где я?", systemImage: "location.fill").font(.subheadline.bold()).padding(15).background(theme.selected.surface, in: Capsule()).shadow(color: .black.opacity(0.15), radius: 8) }
            }
            ActionButton(title: "Создать публикацию", symbol: "plus") { create = true }
        }.padding(14)
    }
    private func choose(_ value: CommunityCategory?) { withAnimation(.easeInOut(duration: 0.2)) { category = value; categoriesOpen = false } }
}
struct ClusterList: View {
    var group: MapGroup
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            List(group.entries) { entry in
                NavigationLink {
                    if let post = entry.post { PostDetail(postID: post.id) }
                    else if let event = entry.event { EventDetail(event: event) }
                } label: { Label(entry.title, systemImage: entry.symbol) }
            }.navigationTitle("В этом месте: \(group.entries.count)")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
        }
    }
}
