import SwiftUI
import MapKit

struct PostCard: View {
    var post: Post
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack { Label(post.category.rawValue, systemImage: post.category.symbol).font(.caption.bold()).foregroundStyle(theme.selected.accent); Spacer(); if post.saved { Image(systemName: "star.fill").foregroundStyle(.yellow) }; Text(post.completed ? "Завершено" : post.district).font(.caption).foregroundStyle(.secondary) }
            Text(post.title).font(.title3.bold())
            Text(post.text).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            HStack { Image(systemName: "person.crop.circle"); Text(post.author); Spacer(); if post.category == .company { Text("\(post.participants)/\(post.capacity)").foregroundStyle(theme.selected.secondary) }; Image(systemName: "arrow.up.right") }.font(.caption.bold())
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }
}
struct CommunityView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeStore
    @State private var category: CommunityCategory = .help
    @State private var selection: Post?
    @State private var create = false
    var filtered: [Post] { store.data.posts.filter { $0.category == category && !$0.completed && store.window.includes(start: $0.start, end: $0.endsAt, now: store.clock) && (store.selectedDistrict == "Весь Минск" || $0.district == store.selectedDistrict) } }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text("Люди делают\nгород живым.").font(.system(size: 34, weight: .heavy, design: .rounded))
            DistrictMenu()
            TimeBar()
            ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(CommunityCategory.allCases) { item in Button { withAnimation(.easeInOut(duration: 0.2)) { category = item } } label: { Text(item.rawValue).font(.subheadline.bold()).padding(.horizontal, 16).padding(.vertical, 12).background(category == item ? theme.selected.accent : theme.selected.surface, in: Capsule()).foregroundStyle(category == item && theme.selected.dark ? .black : theme.selected.ink) } } } }
            Text("Демо-сообщество • публикации сохраняются на этом iPhone").font(.caption).foregroundStyle(.secondary)
            if filtered.isEmpty { ContentUnavailableView("Здесь пока тихо", systemImage: category.symbol, description: Text("Создайте первую публикацию в этом районе.")) }
            ForEach(filtered) { post in Button { selection = post } label: { PostCard(post: post) }.buttonStyle(.plain) }
            ActionButton(title: "Создать публикацию", symbol: "plus") { create = true }
        }.padding(20) }.background(theme.selected.background).navigationTitle("Сообщество").navigationBarTitleDisplayMode(.inline).sheet(item: $selection) { PostDetail(postID: $0.id) }.sheet(isPresented: $create) { CreatePostView() }
    }
}
struct CreatePostView: View {
    var event: CityEvent? = nil
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var location: LocationService
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var text = ""
    @State private var category: CommunityCategory = .company
    @State private var district = "Центральный"
    @State private var lost = false
    @State private var point = Point.minsk
    @State private var radius = 300.0
    @State private var area: [Point] = []
    @State private var address = ""
    @State private var start = Date()
    @State private var initialized = false
    @State private var end = Date().addingTimeInterval(86400)
    @State private var capacity = 10
    @State private var map = false
    var valid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && end > max(start, Date()) }
    var body: some View {
        NavigationStack { Form {
            Section("Что происходит?") {
                Picker("Категория", selection: $category) { ForEach(CommunityCategory.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Заголовок", text: $title).onChange(of: title) { _, v in title = String(v.prefix(100)) }
                TextField("Расскажите подробнее", text: $text, axis: .vertical).lineLimit(4...8).onChange(of: text) { _, v in text = String(v.prefix(3000)) }
                if category == .ads { Toggle("Потеряна вещь или питомец", isOn: $lost) }
            }
            Section("Где?") {
                Picker("Район", selection: $district) { ForEach(District.all) { Text($0.name).tag($0.name) } }
                Button { map = true } label: { Label(lost && category == .ads ? "Точка и радиус: \(Int(radius)) м" : "Выбрать точку на карте", systemImage: "map.fill") }
                if !address.isEmpty { Label(address, systemImage: "mappin.and.ellipse").font(.subheadline) }
                if !area.isEmpty { Text("Выбрана область на карте").font(.caption) }
                Text("\(point.lat, specifier: "%.4f"), \(point.lng, specifier: "%.4f")").font(.caption).foregroundStyle(.secondary)
            }
            Section("Срок действия") {
                DatePicker("Начало", selection: $start)
                DatePicker("Окончание", selection: $end, in: start...)
                if category == .company { Stepper("Мест: \(capacity)", value: $capacity, in: 2...100); Text("Групповой чат закрывается в указанное время.").font(.caption).foregroundStyle(.secondary) }
            }
            Section { ActionButton(title: "Опубликовать", symbol: "paperplane.fill") {
                guard valid else { return }
                let post = Post(title: title.trimmingCharacters(in: .whitespacesAndNewlines), text: text.trimmingCharacters(in: .whitespacesAndNewlines), category: category, author: store.data.profile.name, district: district, point: point, endsAt: end, startsAt: start, address: address, area: area.isEmpty ? nil : area, searchRadius: lost && category == .ads ? radius : 0, mine: true, participants: 1, capacity: capacity)
                store.data.posts.insert(post, at: 0); store.save(); dismiss()
            }.disabled(!valid) }
        }.scrollContentBackground(.hidden).background(theme.selected.background).navigationTitle("Новая публикация").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Отмена") { dismiss() } } }
        }
            .sheet(isPresented: $map) { RadiusPicker(point: $point, radius: $radius, area: $area, address: $address, lost: lost && category == .ads) }
            .onAppear { guard !initialized else { return }; initialized = true; district = store.selectedDistrict == "Весь Минск" ? store.data.profile.district : store.selectedDistrict; point = location.point ?? District.all.first(where: { $0.name == district })?.point ?? .minsk; if let event { title = "Идём вместе: " + event.title; text = "Ищу компанию на «\(event.title)», \(event.date) в \(event.time). Билеты каждый приобретает самостоятельно.\n\(event.url)"; district = event.district; point = event.point; address = event.place; start = event.start ?? Date(); end = (event.start ?? Date()).addingTimeInterval(14400) } }
    }
}
struct PostDetail: View {
    let postID: UUID
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.dismiss) var dismiss
    @State private var chat = false
    @State private var review = false
    var post: Post? { store.data.posts.first { $0.id == postID } }
    var body: some View {
        NavigationStack { ScrollView { if let post { VStack(alignment: .leading, spacing: 22) {
            Map { Marker(post.title, coordinate: post.point.coordinate).tint(theme.selected.accent); if let area = post.area, area.count >= 3 { MapPolygon(coordinates: area.map(\.coordinate)).foregroundStyle(theme.selected.accent.opacity(0.2)).stroke(theme.selected.accent, lineWidth: 2) } else if post.searchRadius > 0 { MapCircle(center: post.point.coordinate, radius: post.searchRadius).foregroundStyle(theme.selected.accent.opacity(0.2)).stroke(theme.selected.accent, lineWidth: 2) } }.mapStyle(theme.mapStyle).frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 25))
            Label(post.category.rawValue, systemImage: post.category.symbol).foregroundStyle(theme.selected.accent)
            Text(post.title).font(.largeTitle.bold())
            Text(post.text).lineSpacing(5)
            if let address = post.address, !address.isEmpty { Label(address, systemImage: "mappin.circle") }
            Text("Начало: \(post.start.formatted(date: .abbreviated, time: .shortened))").font(.subheadline)
            Label(post.district, systemImage: "mappin.and.ellipse")
            Label(post.author, systemImage: "person.crop.circle")
            Text("Действует до \(post.endsAt.formatted(date: .abbreviated, time: .shortened))").font(.subheadline).foregroundStyle(.secondary)
            if post.category == .company {
                ProgressView(value: Double(post.participants), total: Double(post.capacity))
                Text("\(post.participants) из \(post.capacity) участников")
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let active = !post.completed && post.endsAt > context.date
                    if post.joined || post.mine { ActionButton(title: active ? "Открыть чат компании" : "Открыть архив чата", symbol: "bubble.left.and.bubble.right.fill") { chat = true } }
                    else { ActionButton(title: active ? "Присоединиться и открыть чат" : "Активность завершена", symbol: "person.badge.plus") { store.update(postID) { p in guard p.active && p.participants < p.capacity else { return }; p.joined = true; p.participants += 1 }; if self.post?.joined == true { chat = true } }.disabled(!active || post.participants >= post.capacity) }
                }
                if post.joined { Button("Покинуть компанию", role: .destructive) { store.update(postID) { $0.joined = false; $0.participants = max(0, $0.participants - 1) } } }
            }
            Button { store.update(postID) { $0.saved.toggle() } } label: { Label(post.saved ? "Сохранено" : "Сохранить", systemImage: post.saved ? "star.fill" : "star").foregroundStyle(post.saved ? Color.yellow : theme.selected.accent) }
            if post.mine { Button(post.completed ? "Возобновить публикацию" : "Отметить завершённой") { store.update(postID) { $0.completed.toggle() } } }
            if !post.mine && post.category == .help { Button(post.helped ? "Отменить отметку помощи" : "Я помог — отметить выполненной") { store.update(postID) { $0.helped.toggle() } } }
            if !post.mine && (post.helped || (post.joined && !post.active)) { Button("Оставить отзыв") { review = true } }
        }.padding(22) } }.background(theme.selected.background).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }.sheet(isPresented: $chat) { ActivityChat(postID: postID) }.sheet(isPresented: $review) { WriteReview(postID: postID) }
        }
    }
}
struct ActivityChat: View {
    let postID: UUID
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var message = ""
    var body: some View {
        NavigationStack { TimelineView(.periodic(from: .now, by: 1)) { context in
            let post = store.data.posts.first { $0.id == postID }
            let writable = (post?.endsAt ?? .distantPast) > context.date && post?.completed == false && (post?.joined == true || post?.mine == true)
            VStack {
                Text(writable ? "Чат открыт до \(post!.endsAt.formatted(date: .abbreviated, time: .shortened))" : "Активность закончилась • чат доступен для чтения").font(.caption).padding()
                Text("Локальный прототип: сообщения видны только на этом устройстве. Для переписки с участниками нужен сервер.").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                ScrollView { LazyVStack(alignment: .trailing, spacing: 12) { ForEach(store.data.messages.filter { $0.postID == postID }) { item in VStack(alignment: .trailing) { Text(item.text); Text(item.date, style: .time).font(.caption2).foregroundStyle(.secondary) }.padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 18)) } }.padding() }
                HStack { TextField("Сообщение", text: $message, axis: .vertical).lineLimit(1...4).textFieldStyle(.roundedBorder); Button { let text = message.trimmingCharacters(in: .whitespacesAndNewlines); guard writable, !text.isEmpty else { return }; store.data.messages.append(ChatMessage(postID: postID, text: String(text.prefix(2000)))); store.save(); message = "" } label: { Image(systemName: "arrow.up.circle.fill").font(.title) }.disabled(!writable || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }.padding().disabled(!writable)
            }
        }.navigationTitle("Чат компании").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } } }
}

}
