import Foundation

enum ScheduleWindow: String, CaseIterable, Identifiable {
    case now = "Сейчас", today = "Сегодня", tomorrow = "Завтра", threeDays = "3 дня"
    var id: String { rawValue }
    static var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Minsk")!; return c }
    func interval(at now: Date) -> DateInterval {
        let c = Self.calendar, today = c.startOfDay(for: now)
        switch self {
        case .now: return DateInterval(start: now, duration: 1)
        case .today: return DateInterval(start: today, end: c.date(byAdding: .day, value: 1, to: today)!)
        case .tomorrow: return DateInterval(start: c.date(byAdding: .day, value: 1, to: today)!, end: c.date(byAdding: .day, value: 2, to: today)!)
        case .threeDays: return DateInterval(start: now, end: c.date(byAdding: .day, value: 3, to: today)!)
        }
    }
    func includes(start: Date, end: Date, now: Date = Date()) -> Bool {
        guard end > start else { return false }
        if self == .now { return start <= now && end > now }
        let range = interval(at: now)
        return start < range.end && end > max(range.start, now)
    }
}

enum SearchText {
    static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
            .replacingOccurrences(of: "ё", with: "е")
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
    static func matches(_ query: String, in text: String) -> Bool {
        let haystack = normalize(text)
        return normalize(query).split(separator: " ").allSatisfy { haystack.contains($0) }
    }
}
