import SwiftUI
import MapKit

struct CityEvent: Identifiable, Codable {
    var id: String; var title: String; var place: String; var district: String
    var lat: Double; var lng: Double; var date: String; var time: String; var startAt: String
    var price: String; var age: String; var url: String; var image: String; var source: String; var description: String
    var point: Point { Point(lat, lng) }
    var start: Date? { ISO8601DateFormatter().date(from: startAt) }
    func matches(_ window: ScheduleWindow, now: Date) -> Bool {
        guard let start else { return false }
        return window.includes(start: start, end: start.addingTimeInterval(7200), now: now)
    }
    var upcoming: Bool { (start ?? .distantPast) > Date().addingTimeInterval(-7200) }
}
struct EventCatalog: Codable { var events: [CityEvent]; var fetchedAt: Double }
enum TicketproParser {
    static func capture(_ pattern: String, _ input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)), match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: input) else { return "" }
        return String(input[range])
    }
    static func clean(_ text: String) -> String {
        var value = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (key, replacement) in ["&quot;":"\"", "&amp;":"&", "&nbsp;":" ", "&#39;":"'", "&laquo;":"«", "&raquo;":"»", "&ndash;":"–", "&mdash;":"—"] { value = value.replacingOccurrences(of: key, with: replacement) }
        return value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func parse(_ html: String, known: [CityEvent]) -> [CityEvent] {
        var result: [CityEvent] = []; var seen = Set<String>()
        for block in html.components(separatedBy: "class=\"ticket-box\"").dropFirst() {
            func field(_ cls: String) -> String { clean(capture("<div[^>]*class=\"[^\"]*" + cls + "[^\"]*\"[^>]*>(.*?)</div>", block)) }
            let title = field("ticket-box__title"), place = field("ticket-box__place")
            guard let venue = known.first(where: { $0.place == place }), !title.isEmpty else { continue }
            let path = capture("<a[^>]*href=\"([^\"]+)\"", block)
            guard let link = URL(string: path, relativeTo: URL(string: "https://www.ticketpro.by/"))?.absoluteURL, link.host == "www.ticketpro.by", seen.insert(link.absoluteString).inserted else { continue }
            let day = field("ticket-box__date"), time = field("ticket-box__time")
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Minsk"); formatter.dateFormat = "dd.MM.yyyy HH:mm"
            guard let start = formatter.date(from: String(day.prefix(10)) + " " + (time.isEmpty ? "00:00" : time)) else { continue }
            let picture = capture("<img[^>]*src=\"([^\"]+)\"", block)
            let old = known.first { $0.url == link.absoluteString }
            result.append(CityEvent(id: link.absoluteString, title: title, place: place, district: venue.district, lat: venue.lat, lng: venue.lng, date: day, time: time, startAt: ISO8601DateFormatter().string(from: start), price: field("ticket-box__price"), age: field("ticket-box__age"), url: link.absoluteString, image: URL(string: picture, relativeTo: URL(string: "https://www.ticketpro.by/"))?.absoluteString ?? "", source: "Ticketpro", description: old?.description ?? "\(title). Событие на площадке «\(place)». Дата и стоимость получены из афиши Ticketpro. Полная программа и изменения — на странице билетного оператора."))
        }
        return result.sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }
}
@MainActor final class EventsStore: ObservableObject {
    @Published var catalog = EventCatalog(events: [], fetchedAt: 0)
    @Published var favorites: [String: CityEvent] = [:]
    @Published var loading = false
    @Published var status = "Сохранённая подборка Ticketpro"
    private var seed: [CityEvent] = []
    private var file: URL { URL.documentsDirectory.appending(path: "nextu-events.json") }
    private var favoritesFile: URL { URL.documentsDirectory.appending(path: "nextu-favorite-events.json") }
    func isSaved(_ event: CityEvent) -> Bool { favorites[event.url] != nil }
    func toggleSaved(_ event: CityEvent) {
        if isSaved(event) { favorites.removeValue(forKey: event.url) } else { favorites[event.url] = event }
        do { try JSONEncoder().encode(favorites).write(to: favoritesFile, options: .atomic) }
        catch { status = "Не удалось сохранить избранное. Повторите попытку." }
    }
    var upcoming: [CityEvent] { catalog.events.filter(\.upcoming) }
    init() {
        if let data = try? Data(contentsOf: favoritesFile), let saved = try? JSONDecoder().decode([String: CityEvent].self, from: data) { favorites = saved }
        if let url = Bundle.main.url(forResource: "events", withExtension: "json"), let data = try? Data(contentsOf: url), let c = try? JSONDecoder().decode(EventCatalog.self, from: data) { catalog = c; seed = c.events }
        if let data = try? Data(contentsOf: file), let cached = try? JSONDecoder().decode(EventCatalog.self, from: data) { catalog = cached }
    }
    func refresh() async {
        guard !loading else { return }; loading = true; defer { loading = false }
        do {
            var request = URLRequest(url: URL(string: "https://www.ticketpro.by/")!); request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200, let html = String(data: data, encoding: .utf8) else { throw URLError(.badServerResponse) }
            let venues = seed + catalog.events
            let parsed = await Task.detached(priority: .utility) { TicketproParser.parse(html, known: venues) }.value
            guard !parsed.isEmpty else { throw URLError(.cannotParseResponse) }
            for event in parsed where favorites[event.url] != nil { favorites[event.url] = event }
            if let data = try? JSONEncoder().encode(favorites) { try? data.write(to: favoritesFile, options: .atomic) }
            catalog = EventCatalog(events: parsed, fetchedAt: Date().timeIntervalSince1970)
            status = "Обновлено с Ticketpro"
            do { try JSONEncoder().encode(catalog).write(to: file, options: .atomic) } catch { status = "Обновлено • не удалось сохранить офлайн" }
        } catch { status = "Источник недоступен • сохранённая подборка" }
    }
}
struct EventPoster: View {
    var event: CityEvent
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: URL(string: event.image)) { image in image.resizable().scaledToFill() } placeholder: {
                ZStack { theme.selected.gradient; Image(systemName: "sparkles.tv").font(.system(size: 55)).foregroundStyle(.white.opacity(0.75)) }
            }.frame(width: geo.size.width, height: geo.size.height).clipped()
        }
    }
}
struct EventsView: View {
    @EnvironmentObject var events: EventsStore
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeStore
    @State private var query = ""
    @State private var selected: CityEvent?
    @State private var onlySaved = false
    @State private var usePeriod = false
    var filtered: [CityEvent] {
        let source = onlySaved ? Array(events.favorites.values) : events.upcoming
        return source.filter {
            (store.selectedDistrict == "Весь Минск" || $0.district == store.selectedDistrict)
            && SearchText.matches(query, in: $0.title + " " + $0.place + " " + $0.description)
            && (!usePeriod || $0.matches(store.window, now: store.clock))
        }.sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("ТВОЙ ГОРОД. ТВОИ ПЛАНЫ.").font(.caption.bold()).tracking(2).foregroundStyle(theme.selected.secondary)
                Text("Выйди навстречу\nвпечатлениям.").font(.system(size: 34, weight: .heavy, design: .rounded))
                DistrictMenu()
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Артист, событие или площадка", text: $query).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Очистить поиск") }
                }.padding(14).background(theme.selected.surface, in: RoundedRectangle(cornerRadius: 16))
                HStack {
                    Toggle(isOn: $onlySaved) { Label("Избранное", systemImage: "star.fill").foregroundStyle(onlySaved ? Color.yellow : theme.selected.ink) }.toggleStyle(.button)
                    Toggle("Период", isOn: $usePeriod).toggleStyle(.button)
                    Spacer()
                    Text("\(filtered.count) найдено").font(.caption).foregroundStyle(.secondary)
                }
                if usePeriod { TimeBar() }
                HStack { VStack(alignment: .leading) { Text(events.status); Text(Date(timeIntervalSince1970: events.catalog.fetchedAt), format: .dateTime.day().month().year().hour().minute()) }.font(.caption).foregroundStyle(.secondary); Spacer(); if events.loading { ProgressView() } else { Button { Task { await events.refresh() } } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Обновить афишу") } }
                if filtered.isEmpty { ContentUnavailableView("Пока нет событий", systemImage: "calendar", description: Text("Попробуйте другой район или обновите подборку.")) }
                ForEach(filtered) { event in
                    Button { selected = event } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            EventPoster(event: event).frame(height: 240).overlay(alignment: .topLeading) { Text(event.age).font(.caption.bold()).padding(9).background(.black.opacity(0.7), in: Capsule()).foregroundStyle(.white).padding(14) }
                            VStack(alignment: .leading, spacing: 10) {
                                Text(event.date + " · " + event.time).font(.caption.bold()).foregroundStyle(theme.selected.accent)
                                Text(event.title).font(.title2.bold()).multilineTextAlignment(.leading)
                                Label(event.place, systemImage: "mappin.and.ellipse").font(.subheadline).foregroundStyle(.secondary)
                                HStack { Text(event.price).font(.headline); Spacer(); Image(systemName: "arrow.up.right") }
                            }.padding(20)
                        }.background(theme.selected.surface).clipShape(RoundedRectangle(cornerRadius: 28))
                    }.buttonStyle(.plain)
                        .overlay(alignment: .topTrailing) { FavoriteEventButton(event: event).padding(14) }
                        .scrollTransition { content, phase in content.opacity(phase.isIdentity ? 1 : 0.7).scaleEffect(phase.isIdentity ? 1 : 0.97) }
                }
                Text("Подборка ближайших событий на известных площадках Минска. Источник — Ticketpro; состав и цены могут меняться. Актуальные условия — у оператора.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.background(theme.selected.background).navigationTitle("События").navigationBarTitleDisplayMode(.inline).refreshable { await events.refresh() }
            .sheet(item: $selected) { EventDetail(event: $0) }
    }
}
struct EventDetail: View {
    let event: CityEvent
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var store: AppStore
    @State private var company = false
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 22) {
            EventPoster(event: event).frame(height: 310).clipShape(RoundedRectangle(cornerRadius: 28)).overlay(alignment: .topTrailing) { FavoriteEventButton(event: event).padding(14) }
            Text(event.title).font(.largeTitle.bold())
            Label(event.date + " · " + event.time, systemImage: "calendar")
            Label(event.place, systemImage: "mappin.and.ellipse")
            Text(event.description).lineSpacing(5)
            Text(event.price + " · " + event.age).font(.headline)
            if let url = URL(string: event.url) { Link(destination: url) { Label("Программа и билеты · Ticketpro", systemImage: "arrow.up.right.square").frame(maxWidth: .infinity).padding().background(theme.selected.gradient, in: RoundedRectangle(cornerRadius: 18)).foregroundStyle(theme.selected.dark ? .black : .white) } }
            ActionButton(title: "Найти компанию", symbol: "person.2.fill") { company = true }
            Text("Покупка билетов — на сайте оператора. Публикация в NextU не является билетом.").font(.caption).foregroundStyle(.secondary)
        }.padding(20) }.background(theme.selected.background).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }.sheet(isPresented: $company) { CreatePostView(event: event) } }
    }
}

struct FavoriteEventButton: View {
    let event: CityEvent
    @EnvironmentObject var events: EventsStore
    var body: some View {
        Button { events.toggleSaved(event) } label: {
            Image(systemName: events.isSaved(event) ? "star.fill" : "star")
                .font(.title3.bold()).foregroundStyle(events.isSaved(event) ? Color.yellow : Color.white)
                .padding(12).background(.black.opacity(0.65), in: Circle())
        }.buttonStyle(.plain).accessibilityLabel(events.isSaved(event) ? "Убрать из избранного" : "Сохранить событие")
    }
}
