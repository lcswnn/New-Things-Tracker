import Foundation

// A single Stay's time window, reduced to what Stage 4 needs — decoupled from the SwiftData Stay
// model so classification stays pure and testable.
nonisolated struct StayTimeWindow: Sendable, Equatable {
    var placeKey: String
    var startDate: Date
}

nonisolated struct HomeWorkClassification: Sendable, Equatable {
    var homePlaceKey: String?
    var workPlaceKey: String?
}

// Stage 4: aggregates Stay time windows per place to suppress home/work from ever becoming a
// "first". Gated behind a minimum-evidence floor (tuning.minEvidenceDaysForHomeWork) — without it,
// a fresh install with a few days of history would nominate, and then suppress, a garbage home.
nonisolated enum HomeWorkClassifier {

    static func classify(
        _ windows: [StayTimeWindow],
        tuning: PipelineTuning,
        calendar: Calendar
    ) -> HomeWorkClassification {
        let allDays = Set(windows.map { calendar.startOfDay(for: $0.startDate) })
        guard allDays.count >= tuning.minEvidenceDaysForHomeWork else {
            return HomeWorkClassification(homePlaceKey: nil, workPlaceKey: nil)
        }

        let home = classifyHome(windows, allDays: allDays, tuning: tuning, calendar: calendar)
        let work = classifyWork(windows, excluding: home, tuning: tuning, calendar: calendar)
        return HomeWorkClassification(homePlaceKey: home, workPlaceKey: work)
    }

    private static func classifyHome(
        _ windows: [StayTimeWindow], allDays: Set<Date>, tuning: PipelineTuning, calendar: Calendar
    ) -> String? {
        var nightDaysByPlace: [String: Set<Date>] = [:]
        for window in windows where isOvernightHour(window.startDate, tuning: tuning, calendar: calendar) {
            nightDaysByPlace[window.placeKey, default: []].insert(calendar.startOfDay(for: window.startDate))
        }
        guard let best = nightDaysByPlace.max(by: { $0.value.count < $1.value.count }) else { return nil }
        let fraction = Double(best.value.count) / Double(allDays.count)
        return fraction >= tuning.homeMinNightPresenceFraction ? best.key : nil
    }

    private static func classifyWork(
        _ windows: [StayTimeWindow], excluding home: String?, tuning: PipelineTuning, calendar: Calendar
    ) -> String? {
        var weeksByPlace: [String: Set<DateComponents>] = [:]
        for window in windows where window.placeKey != home && isWeekdayWorkHour(window.startDate, calendar: calendar) {
            let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: window.startDate)
            weeksByPlace[window.placeKey, default: []].insert(weekComponents)
        }
        guard let best = weeksByPlace.max(by: { $0.value.count < $1.value.count }) else { return nil }
        return best.value.count >= tuning.workMinDistinctWeeks ? best.key : nil
    }

    private static func isOvernightHour(_ date: Date, tuning: PipelineTuning, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= tuning.homeNightStartHour || hour < tuning.homeNightEndHour
    }

    private static func isWeekdayWorkHour(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday ... 7 = Saturday
        guard (2...6).contains(weekday) else { return false }
        let hour = calendar.component(.hour, from: date)
        return (9..<17).contains(hour)
    }
}
