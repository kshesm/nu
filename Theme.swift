import SwiftUI
import MapKit

enum AppTheme: String, CaseIterable, Identifiable {
    case night, day, aurora, sunset
    var id: String { rawValue }
    var title: String { switch self { case .night: "NextU Night"; case .day: "NextU Day"; case .aurora: "Aurora"; case .sunset: "Sunset" } }
    var subtitle: String { switch self { case .night: "Чёрный · розовый · голубой"; case .day: "Светлый · синий · розовый"; case .aurora: "Полярная ночь · мята · лиловый"; case .sunset: "Кремовый · коралл · индиго" } }
    var dark: Bool { self == .night || self == .aurora }
    var background: Color { Color(hex: dark ? (self == .night ? 0x090B12 : 0x081D28) : (self == .day ? 0xF3F6FF : 0xFFF5EB)) }
    var surface: Color { Color(hex: dark ? (self == .night ? 0x191B29 : 0x123442) : 0xFFFFFF) }
    var ink: Color { Color(hex: dark ? 0xF6F5FF : 0x15223C) }
    var accent: Color { Color(hex: self == .aurora ? 0x68E9C6 : self == .sunset ? 0xEC725E : self == .day ? 0xCD377D : 0xFF85C2) }
    var secondary: Color { Color(hex: self == .aurora ? 0xAE99FF : self == .sunset ? 0x6377D7 : self == .day ? 0x367DCE : 0x77CFFF) }
    var gradient: LinearGradient { LinearGradient(colors: [accent, secondary], startPoint: .topLeading, endPoint: .bottomTrailing) }
}
extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255)/255, green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255) }
}
@MainActor final class ThemeStore: ObservableObject {
    @Published var satellite = UserDefaults.standard.bool(forKey: "nextu.satellite") {
        didSet { UserDefaults.standard.set(satellite, forKey: "nextu.satellite") }
    }
    var mapStyle: MapStyle { satellite ? .hybrid(elevation: .flat, pointsOfInterest: .excludingAll) : .standard(elevation: .flat, pointsOfInterest: .excludingAll) }
    @Published var selected: AppTheme { didSet { UserDefaults.standard.set(selected.rawValue, forKey: "nextu.theme") } }
    init() { selected = AppTheme(rawValue: UserDefaults.standard.string(forKey: "nextu.theme") ?? "night") ?? .night }
}
struct Surface: ViewModifier {
    @EnvironmentObject var theme: ThemeStore
    func body(content: Content) -> some View { content.padding(18).background(theme.selected.surface, in: RoundedRectangle(cornerRadius: 25)).overlay(RoundedRectangle(cornerRadius: 25).stroke(theme.selected.secondary.opacity(0.12))) }
}
extension View { func card() -> some View { modifier(Surface()) } }
struct ActionButton: View {
    @EnvironmentObject var theme: ThemeStore
    var title: String
    var symbol: String = "arrow.right"
    var action: () -> Void
    var body: some View { Button(action: action) { Label(title, systemImage: symbol).font(.headline).frame(maxWidth: .infinity).padding(17).foregroundStyle(theme.selected.dark ? .black : .white).background(theme.selected.gradient, in: RoundedRectangle(cornerRadius: 19)) }.buttonStyle(.plain) }
}
struct Brand: View {
    var size: CGFloat = 38
    var body: some View { HStack(spacing: 9) { Image("NextULogo").resizable().scaledToFit().frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.24)); Text("NextU").font(.system(size: size * 0.65, weight: .heavy, design: .rounded)) } }
}

struct TimeBar: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeStore
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(ScheduleWindow.allCases) { item in
                    Button { withAnimation(.easeInOut(duration: 0.2)) { store.window = item } } label: {
                        Text(item.rawValue).font(.subheadline.bold()).padding(.horizontal, 15).padding(.vertical, 11)
                            .foregroundStyle(store.window == item ? (theme.selected.dark ? Color.black : Color.white) : theme.selected.ink)
                            .background(store.window == item ? theme.selected.accent : theme.selected.surface, in: Capsule())
                    }.buttonStyle(.plain).accessibilityAddTraits(store.window == item ? .isSelected : [])
                }
            }
        }
    }
}
