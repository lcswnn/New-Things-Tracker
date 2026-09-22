import Foundation

// Every tunable threshold for the Firsts pipeline in one place, injected everywhere it's used —
// scattered magic numbers would be untunable and untestable independently of the algorithm code.
nonisolated struct PipelineTuning: Sendable, Equatable {
    // Stage 2 — clustering
    var joinDistanceMeters: Double = 120
    var joinTimeGap: TimeInterval = 3 * 3600
    var transitSpeedKmh: Double = 6.0

    // Stage 3 — POI resolution
    var poiSearchRadiusMeters: Double = 75
    var maxPoiSearchRadiusMeters: Double = 250
    var mergeDistanceMeters: Double = 40
    var minPlaceScore: Double = 0.5
    var clearWinnerScoreGap: Double = 0.25
    var minConfidenceToAutoAccept: Double = 0.6

    // Visit-only Stays (no photos): require a real dwell before counting as a First.
    var minVisitDwellSeconds: TimeInterval = 10 * 60

    // Stage 4 — home/work suppression. Gated behind a minimum-evidence floor so a fresh install
    // with a few days of history doesn't nominate (and suppress) a garbage home.
    var minEvidenceDaysForHomeWork: Int = 14
    var homeNightStartHour: Int = 22
    var homeNightEndHour: Int = 6
    var homeMinNightPresenceFraction: Double = 0.4
    var workMinDistinctWeeks: Int = 3

    static let `default` = PipelineTuning()
}
