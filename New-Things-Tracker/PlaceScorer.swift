import Foundation
import CoreLocation

// Evidence about a Stay that feeds the evidence term of the score, independent of which POI
// candidate is being scored against it.
nonisolated struct PlaceScoringContext: Sendable, Equatable {
    var centroid: CLLocationCoordinate2D
    var searchRadiusMeters: Double
    var photoCount: Int
    var dwellMinutes: Double
    var hasVisit: Bool
    var nameHint: Bool = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.centroid.latitude == rhs.centroid.latitude && lhs.centroid.longitude == rhs.centroid.longitude
            && lhs.searchRadiusMeters == rhs.searchRadiusMeters && lhs.photoCount == rhs.photoCount
            && lhs.dwellMinutes == rhs.dwellMinutes && lhs.hasVisit == rhs.hasVisit && lhs.nameHint == rhs.nameHint
    }
}

nonisolated struct ScoredPlaceCandidate: Sendable, Equatable {
    var candidate: POICandidateDraft
    var score: Double
}

nonisolated enum PlaceResolution: Sendable, Equatable {
    case resolved(ScoredPlaceCandidate)
    case needsConfirmation(top: [ScoredPlaceCandidate])
    case noMatch
}

// Stage 3: scores POI candidates against a Stay and decides resolved / needsConfirmation / noMatch.
// Every term is normalized to 0...1 before weighting — the algorithm spec's formula as written
// multiplies a raw meter distance by 0.45, which would dominate the other three terms by orders
// of magnitude; that's fixed here by mapping distance through `1 - min(distance/radius, 1)` first.
nonisolated enum PlaceScorer {

    static func score(_ candidate: POICandidateDraft, against context: PlaceScoringContext) -> Double {
        let distance = GeoMath.distanceMeters(candidate.coordinate, context.centroid)
        let distanceScore = max(0, 1 - min(distance / max(context.searchRadiusMeters, 1), 1))
        let categoryScore = POICategoryMap.weight(for: candidate.categoryGroup)
        let evidenceScore = min(1, 0.15 * Double(context.photoCount) + 0.02 * context.dwellMinutes + (context.hasVisit ? 0.3 : 0))
        let nameHintScore = context.nameHint ? 1.0 : 0.0
        return 0.45 * distanceScore + 0.30 * categoryScore + 0.15 * evidenceScore + 0.10 * nameHintScore
    }

    static func resolve(
        _ candidates: [POICandidateDraft],
        against context: PlaceScoringContext,
        tuning: PipelineTuning = .default
    ) -> PlaceResolution {
        let scored = candidates
            .map { ScoredPlaceCandidate(candidate: $0, score: score($0, against: context)) }
            .sorted { $0.score > $1.score }

        guard let best = scored.first, best.score >= tuning.minPlaceScore else { return .noMatch }

        let runnerUpScore = scored.dropFirst().first?.score ?? 0
        if best.score - runnerUpScore >= tuning.clearWinnerScoreGap {
            return .resolved(best)
        }
        return .needsConfirmation(top: Array(scored.prefix(3)))
    }
}
