import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeStore
    @State private var edit = false
    @State private var reviews = false
    @State private var selected: Post?
    @State private var segment = 0
    var posts: [Post] { store.data.posts.filter { segment == 0 ? $0.mine : segment == 1 ? $0.joined : $0.saved } }
    var body: some View {
        ScrollView { VStack(spacing: 22) {
            Avatar(data: store.data.profile.photo, size: 96).overlay(Circle().stroke(theme.selected.gradient, lineWidth: 3)).padding(.top, 10)
            VStack(spacing: 6) { Text(store.data.profile.name).font(.title.bold()); Text(store.data.profile.district + " район").foregroundStyle(.secondary); if !store.data.profile.bio.isEmpty { Text(store.data.profile.bio).multilineTextAlignment(.center) }; if !store.data.profile.interests.isEmpty { Text(store.data.profile.interests).font(.caption).foregroundStyle(theme.selected.secondary) } }
            ActionButton(title: "Редактировать профиль", symbol: "pencil") { edit = true }
            VStack(alignment: .leading, spacing: 16) {
                HStack { Label("Уровень доверия", systemImage: "checkmark.shield.fill").font(.headline); Spacer(); Text("\(store.trust)/100").font(.title3.bold()).foregroundStyle(theme.selected.accent) }
                ProgressView(value: Double(store.trust), total: 100).tint(theme.selected.accent)
                Text(store.trustLabel).font(.title2.bold())
                HStack { Label("\(store.completedCount) завершено", systemImage: "checkmark.circle"); Spacer(); Label("\(store.helpedCount) помог", systemImage: "hands.sparkles") }.font(.caption)
                Text("+5 за завершённую публикацию, +10 за помощь. В прототипе это ваши отметки; они не подтверждены другими участниками.").font(.caption).foregroundStyle(.secondary)
            }.card()
            Button { reviews = true } label: { HStack { Label("Отзывы", systemImage: "star.bubble.fill").font(.headline); Spacer(); Text("\(store.data.reviews.filter(\.received).count)"); Image(systemName: "chevron.right") }.card() }.buttonStyle(.plain)
            Picker("Публикации", selection: $segment) { Text("Мои").tag(0); Text("Участвую").tag(1); Text("Сохранено").tag(2) }.pickerStyle(.segmented)
            if posts.isEmpty { ContentUnavailableView("Пока пусто", systemImage: "tray", description: Text("Ваши публикации и активности появятся здесь.")) }
            ForEach(posts) { post in Button { selected = post } label: { PostCard(post: post) }.buttonStyle(.plain) }
        }.padding(20) }.background(theme.selected.background).navigationTitle("Профиль").navigationBarTitleDisplayMode(.inline).sheet(isPresented: $edit) { EditProfile() }.sheet(isPresented: $reviews) { ReviewsView() }.sheet(item: $selected) { PostDetail(postID: $0.id) }
    }
}
struct Avatar: View {
    var data: Data?; var size: CGFloat
    var body: some View { Group { if let data, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() } else { Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary) } }.frame(width: size, height: size).clipShape(Circle()) }
}
struct EditProfile: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var draft = Profile()
    @State private var photo: PhotosPickerItem?
    @State private var photoError: String?
    @State private var loadingPhoto = false
    var body: some View {
        NavigationStack { Form {
            Section { HStack { Spacer(); VStack(spacing: 12) { Avatar(data: draft.photo, size: 100); PhotosPicker(selection: $photo, matching: .images) { Label(loadingPhoto ? "Загрузка…" : "Выбрать фото", systemImage: "photo") }; if draft.photo != nil { Button("Удалить фото", role: .destructive) { draft.photo = nil; photo = nil } } }; Spacer() }; if let photoError { Text(photoError).foregroundStyle(.red) } }
            Section("О вас") { TextField("Имя", text: $draft.name).onChange(of: draft.name) { _, v in draft.name = String(v.prefix(60)) }; TextField("О себе", text: $draft.bio, axis: .vertical).lineLimit(3...5).onChange(of: draft.bio) { _, v in draft.bio = String(v.prefix(500)) }; TextField("Интересы", text: $draft.interests).onChange(of: draft.interests) { _, v in draft.interests = String(v.prefix(180)) }; Picker("Район", selection: $draft.district) { ForEach(District.all) { Text($0.name).tag($0.name) } } }
            Section { Text("Профиль и фотография сохраняются на этом iPhone.").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("Ваш профиль").navigationBarTitleDisplayMode(.inline).toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { Button("Сохранить") { draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines); store.data.profile = draft; store.save(); dismiss() }.disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loadingPhoto) }
        } }.onAppear { draft = store.data.profile }.task(id: photo) {
            guard let photo else { return }; loadingPhoto = true; defer { loadingPhoto = false }
            do { guard let data = try await photo.loadTransferable(type: Data.self), let image = UIImage(data: data) else { photoError = "Не удалось открыть фото."; return }; try Task.checkCancellation()
                let side: CGFloat = 600
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
                let scale = max(side / image.size.width, side / image.size.height)
                let output = renderer.image { _ in image.draw(in: CGRect(x: (side - image.size.width * scale)/2, y: (side - image.size.height * scale)/2, width: image.size.width * scale, height: image.size.height * scale)) }
                draft.photo = output.jpegData(compressionQuality: 0.85); photoError = nil
            } catch is CancellationError { } catch { photoError = "Фото недоступно. Попробуйте другое." }
        }
    }
}
struct ReviewsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var received = true
    var rows: [Review] { store.data.reviews.filter { $0.received == received } }
    var body: some View {
        NavigationStack { List {
            Picker("Отзывы", selection: $received) { Text("Обо мне").tag(true); Text("Мои отзывы").tag(false) }.pickerStyle(.segmented)
            if rows.isEmpty { ContentUnavailableView(received ? "Отзывов пока нет" : "Вы ещё не оставляли отзывы", systemImage: "star.bubble", description: Text(received ? "Здесь появятся отзывы участников после подключения общего сервера." : "Отзыв можно оставить после помощи или завершённой активности.")) }
            ForEach(rows) { review in VStack(alignment: .leading, spacing: 8) { Text(received ? review.author : "Для: " + review.recipient).font(.headline); Text(String(repeating: "★", count: review.stars)).foregroundStyle(.orange); Text(review.text); Text(review.date, style: .date).font(.caption).foregroundStyle(.secondary) } }
        }.navigationTitle("Отзывы").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } } }
}
}
struct WriteReview: View {
    var postID: UUID
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var stars = 5
    @State private var text = ""
    var body: some View {
        NavigationStack { Form {
            Section("Как всё прошло?") { HStack { ForEach(1...5, id: \.self) { n in Button { stars = n } label: { Image(systemName: n <= stars ? "star.fill" : "star").font(.title).foregroundStyle(.orange) }.buttonStyle(.plain).accessibilityLabel("\(n) из 5") } }; TextField("Ваш отзыв", text: $text, axis: .vertical).lineLimit(4...8).onChange(of: text) { _, v in text = String(v.prefix(1000)) } }
            Text("Отзыв сохраняется локально и пока не отправляется другому участнику.").font(.caption).foregroundStyle(.secondary)
        }.navigationTitle("Оставить отзыв").toolbar { ToolbarItem(placement: .topBarLeading) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .topBarTrailing) { Button("Сохранить") {
            guard let post = store.data.posts.first(where: { $0.id == postID }), !post.mine, post.helped || (post.joined && !post.active) else { return }
            store.data.reviews.removeAll { $0.postID == postID && !$0.received }
            store.data.reviews.append(Review(postID: postID, author: store.data.profile.name, recipient: post.author, stars: stars, text: text.trimmingCharacters(in: .whitespacesAndNewlines))); store.save(); dismiss()
        }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } }.onAppear { if let old = store.data.reviews.first(where: { $0.postID == postID && !$0.received }) { stars = old.stars; text = old.text } }
    }
}
struct SettingsView: View {
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var location: LocationService
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20) {
            Text("Твой NextU.\nТвоё настроение.").font(.largeTitle.bold())
            Text("Оформление").font(.title2.bold())
            Text("Выберите тему приложения").font(.subheadline).foregroundStyle(.secondary)
            ForEach(AppTheme.allCases) { item in Button { withAnimation(.easeInOut(duration: 0.35)) { theme.selected = item } } label: {
                HStack(spacing: 16) { ZStack { RoundedRectangle(cornerRadius: 17).fill(item.background); Circle().fill(item.gradient).frame(width: 37, height: 37) }.frame(width: 70, height: 70); VStack(alignment: .leading, spacing: 5) { Text(item.title).font(.headline); Text(item.subtitle).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: theme.selected == item ? "checkmark.circle.fill" : "circle").foregroundStyle(theme.selected.accent) }.card()
            }.buttonStyle(.plain) }
            VStack(alignment: .leading, spacing: 16) { Label("Геолокация", systemImage: "location.fill").font(.headline); Text("Нужна, чтобы открыть карту рядом с вами. Фоновое слежение не используется.").font(.subheadline).foregroundStyle(.secondary); Button("Определить местоположение") { location.request() }; Button("Настройки доступа iPhone") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } } }.card()
            VStack(alignment: .leading, spacing: 14) {
                Text("Вид карты").font(.title2.bold())
                Picker("Вид карты", selection: $theme.satellite) {
                    Text("Схема").tag(false)
                    Text("Спутник").tag(true)
                }.pickerStyle(.segmented)
                Text("Спутниковые снимки с названиями улиц. Выбор применяется ко всем картам.").font(.caption).foregroundStyle(.secondary)
            }.card()
            NavigationLink { AboutContent() } label: { Label("О приложении", systemImage: "info.circle").frame(maxWidth: .infinity, alignment: .leading).card() }
            NavigationLink { SupportView() } label: { Label("Техническая поддержка", systemImage: "questionmark.bubble").frame(maxWidth: .infinity, alignment: .leading).card() }
            Text("NextU · прототип для iPhone\nКарта: Apple Maps. Афиша: Ticketpro. Профиль, объявления, сообщения и отзывы хранятся локально.").font(.caption).foregroundStyle(.secondary)
        }.padding(20) }.background(theme.selected.background).navigationTitle("Настройки").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } } }
}

}
