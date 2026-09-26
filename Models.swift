import SwiftUI
import CoreLocation

struct Point: Codable, Equatable {
    var lat: Double
    var lng: Double
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
    init(_ lat: Double, _ lng: Double) { self.lat = lat; self.lng = lng }
    init(_ c: CLLocationCoordinate2D) { lat = c.latitude; lng = c.longitude }
    static let minsk = Point(53.9045, 27.5714)
}
struct District: Identifiable, Hashable {
    var name: String; var lat: Double; var lng: Double
    var id: String { name }
    var point: Point { Point(lat, lng) }
    static let all: [District] = [
        .init(name: "Центральный", lat: 53.929, lng: 27.515), .init(name: "Советский", lat: 53.940, lng: 27.583),
        .init(name: "Первомайский", lat: 53.944, lng: 27.660), .init(name: "Партизанский", lat: 53.903, lng: 27.625),
        .init(name: "Заводской", lat: 53.862, lng: 27.678), .init(name: "Ленинский", lat: 53.869, lng: 27.600),
        .init(name: "Октябрьский", lat: 53.857, lng: 27.539), .init(name: "Московский", lat: 53.871, lng: 27.481),
        .init(name: "Фрунзенский", lat: 53.919, lng: 27.459)
    ]
}
enum CommunityCategory: String, CaseIterable, Codable, Identifiable {
    case help = "Помощь", company = "Компания", events = "События", ads = "Объявления"
    var id: String { rawValue }
    var symbol: String { switch self { case .help: "hands.sparkles.fill"; case .company: "person.2.fill"; case .events: "sparkles"; case .ads: "megaphone.fill" } }
}
struct Post: Identifiable, Codable {
    var id = UUID()
    var title: String; var text: String; var category: CommunityCategory
    var author: String; var district: String; var point: Point
    var created = Date(); var endsAt = Date().addingTimeInterval(86400)
    var startsAt: Date?
    var address: String?
    var area: [Point]?
    var searchRadius: Double = 0
    var mine = false; var joined = false; var completed = false; var helped = false; var saved = false
    var participants = 3; var capacity = 10
    var start: Date { startsAt ?? created }
    var active: Bool { !completed && endsAt > Date() }
}
struct Review: Identifiable, Codable {
    var id = UUID(); var postID: UUID; var author: String; var recipient: String
    var stars: Int; var text: String; var date = Date(); var received = false
}
struct ChatMessage: Identifiable, Codable {
    var id = UUID(); var postID: UUID; var text: String; var date = Date()
}
struct Profile: Codable {
    var name = "Новый сосед"; var bio = ""; var district = "Центральный"; var interests = ""
    var photo: Data?
}
struct LocalState: Codable {
    var profile = Profile(); var posts: [Post] = []; var reviews: [Review] = []; var messages: [ChatMessage] = []
}
@MainActor final class AppStore: ObservableObject {
    @Published var data = LocalState()
    @Published var error: String?
    @Published var window: ScheduleWindow = .today
    @Published var clock = Date()
    @Published var selectedDistrict: String = "Весь Минск"
    private var file: URL { URL.documentsDirectory.appending(path: "nextu-state-v1.json") }
    init() {
        if FileManager.default.fileExists(atPath: file.path) {
            do { data = try JSONDecoder().decode(LocalState.self, from: Data(contentsOf: file)) }
            catch { self.error = "Не удалось прочитать данные. Сохранённый файл не изменён." }
        } else { data.posts = Self.samples }
    }
    func save() {
        do { try JSONEncoder().encode(data).write(to: file, options: .atomic) }
        catch { self.error = "Не удалось сохранить изменения на устройстве." }
    }
    func update(_ id: UUID, _ action: (inout Post) -> Void) { guard let i = data.posts.firstIndex(where: {$0.id == id}) else { return }; action(&data.posts[i]); save() }
    var completedCount: Int { data.posts.filter { $0.mine && $0.completed }.count }
    var helpedCount: Int { data.posts.filter { !$0.mine && $0.category == .help && $0.helped }.count }
    var trust: Int { min(100, completedCount * 5 + helpedCount * 10) }
    var trustLabel: String { trust >= 75 ? "Опора района" : trust >= 40 ? "Надёжный сосед" : trust >= 15 ? "Активный сосед" : "Новый сосед" }
    static var samples: [Post] {
        District.all.enumerated().flatMap { i, d in
            [Post(title: ["Футбол после работы", "Прогулка и кофе", "Настолки с соседями"][i % 3], text: "Собираемся небольшой компанией. Присоединяйтесь — новым соседям всегда рады!", category: .company, author: "Команда района", district: d.name, point: d.point),
             Post(title: "Нужна помощь с переездом", text: "Помочь перенести несколько коробок. Время обсудим вместе.", category: .help, author: "Сосед", district: d.name, point: Point(d.lat + 0.004, d.lng + 0.006)),
             Post(title: "Обмен книгами во дворе", text: "Приносите прочитанные книги и знакомьтесь с соседями.", category: .events, author: "Книжный клуб", district: d.name, point: Point(d.lat - 0.003, d.lng - 0.003))]
        } + [Post(title: "Потеряны AirPods", text: "Белый чехол. Могли остаться по дороге через парк. Если нашли — откликнитесь.", category: .ads, author: "Алексей", district: "Партизанский", point: Point(53.902, 27.574), searchRadius: 350)]
    }
}
