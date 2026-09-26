import Foundation

@main struct LogicChecks {
    static func main() {
        let parser = ISO8601DateFormatter()
        func d(_ s: String) -> Date { parser.date(from: s)! }
        let now = d("2026-09-26T12:00:00+03:00")
        assert(ScheduleWindow.now.includes(start: now, end: now.addingTimeInterval(60), now: now))
        assert(!ScheduleWindow.now.includes(start: now.addingTimeInterval(1), end: now.addingTimeInterval(60), now: now))
        assert(!ScheduleWindow.now.includes(start: now.addingTimeInterval(-60), end: now, now: now))
        assert(!ScheduleWindow.today.includes(start: d("2026-09-27T00:00:00+03:00"), end: d("2026-09-27T01:00:00+03:00"), now: now))
        assert(ScheduleWindow.tomorrow.includes(start: d("2026-09-26T23:00:00+03:00"), end: d("2026-09-27T01:00:00+03:00"), now: now))
        assert(!ScheduleWindow.tomorrow.includes(start: now, end: d("2026-09-27T00:00:00+03:00"), now: now))
        assert(ScheduleWindow.threeDays.includes(start: d("2026-09-28T23:00:00+03:00"), end: d("2026-09-29T02:00:00+03:00"), now: now))
        assert(!ScheduleWindow.threeDays.includes(start: d("2026-09-29T00:00:00+03:00"), end: d("2026-09-29T01:00:00+03:00"), now: now))
        assert(!ScheduleWindow.today.includes(start: now, end: now, now: now))
        assert(SearchText.matches("  ФАДЕЕВ  ", in: "Концерт Максима Фадеева"))
        assert(SearchText.matches("елка минск", in: "Ёлка — концерт в Минске"))
        assert(SearchText.matches("", in: "Любой концерт"))
        assert(!SearchText.matches("джаз", in: "Футбольный матч"))
        print("PASS: 13 schedule and search checks")
    }
}
