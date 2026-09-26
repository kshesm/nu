import SwiftUI

@main struct NextUApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var theme = ThemeStore()
    @StateObject private var location = LocationService()
    @StateObject private var events = EventsStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).environmentObject(theme).environmentObject(location).environmentObject(events)
                .tint(theme.selected.accent).foregroundStyle(theme.selected.ink).preferredColorScheme(theme.selected.dark ? .dark : .light)
        }
    }
}
struct RootView: View {
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var location: LocationService
    @EnvironmentObject var events: EventsStore
    @State private var splash = true
    @State private var settings = false
    @State private var about = false
    @Environment(\.scenePhase) var scenePhase
    @State private var locationPrompt = false
    @AppStorage("nextu.locationExplained") private var locationExplained = false
    var body: some View {
        ZStack {
            TabView {
                shell { NearbyView() }.tabItem { Label("Карта", systemImage: "map.fill") }
                shell { CommunityView() }.tabItem { Label("Сообщество", systemImage: "person.2.fill") }
                shell { EventsView() }.tabItem { Label("События", systemImage: "ticket.fill") }
                shell { ProfileView() }.tabItem { Label("Профиль", systemImage: "person.crop.circle") }
            }.toolbarBackground(theme.selected.surface, for: .tabBar).toolbarBackground(.visible, for: .tabBar)
            if splash { SplashView().transition(.opacity).zIndex(10) }
        }.sheet(isPresented: $settings) { SettingsView() }
            .sheet(isPresented: $about) { AboutView() }
            .alert("Что происходит рядом с вами?", isPresented: $locationPrompt) {
                Button("Разрешить геолокацию") { location.request() }
                Button("Выберу район сам", role: .cancel) { }
            } message: { Text("NextU определит ваше местоположение и приблизит карту. Доступ используется только при работе с приложением.") }
            .alert("Не удалось сохранить данные", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("Понятно") { store.error = nil } } message: { Text(store.error ?? "") }
            .task {
                // The in-app splash lasts two seconds independently of networking.
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeOut(duration: 0.25)) { splash = false }
                if !locationExplained { locationExplained = true; locationPrompt = true }
                else if location.status == .authorizedAlways || location.status == .authorizedWhenInUse { location.request() }
            }.task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await events.refresh()
                var ticks = 0
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(30)) } catch { return }
                    store.clock = Date(); ticks += 1
                    if ticks % 10 == 0 { await events.refresh() }
                }
            }
    }
    func shell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack { content().toolbar { ToolbarItem(placement: .topBarLeading) { Button { about = true } label: { Brand(size: 30) }.buttonStyle(.plain).accessibilityLabel("NextU — о приложении") }; ToolbarItem(placement: .principal) { Text("Ближе к людям").font(.caption.bold()).foregroundStyle(theme.selected.secondary).lineLimit(1).minimumScaleFactor(0.7) }; ToolbarItem(placement: .topBarTrailing) { Button { settings = true } label: { Image(systemName: "slider.horizontal.3").font(.headline) }.accessibilityLabel("Настройки") } }.toolbarBackground(theme.selected.background, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar) }
    }
}
struct SplashView: View {
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var animate = false
    var body: some View {
        ZStack {
            theme.selected.background.ignoresSafeArea()
            Circle().fill(theme.selected.accent.opacity(0.17)).frame(width: 280, height: 280).blur(radius: 50).offset(x: animate ? -80 : 50, y: -110)
            Circle().fill(theme.selected.secondary.opacity(0.2)).frame(width: 270, height: 270).blur(radius: 50).offset(x: animate ? 80 : -50, y: 100)
            VStack(spacing: 22) {
                ZStack { Circle().stroke(theme.selected.gradient, lineWidth: 2).frame(width: 200, height: 200).scaleEffect(animate ? 1.15 : 0.85).opacity(animate ? 0.1 : 0.8); Image("NextULogo").resizable().scaledToFit().frame(width: 142, height: 142).clipShape(RoundedRectangle(cornerRadius: 34)).shadow(color: theme.selected.accent.opacity(0.3), radius: 35).scaleEffect(animate ? 1 : 0.87).rotationEffect(.degrees(animate ? 0 : -7)) }
                Text("NextU").font(.system(size: 49, weight: .heavy, design: .rounded)).tracking(-2)
                Text("БЛИЖЕ К ЛЮДЯМ").font(.caption2.bold()).tracking(2.5).foregroundStyle(theme.selected.secondary)
                Capsule().fill(theme.selected.gradient).frame(width: animate ? 130 : 12, height: 4).padding(.top, 18)
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel("NextU. Загрузка приложения.")
            .onAppear { withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.75)) { animate = true } }
    }
}
