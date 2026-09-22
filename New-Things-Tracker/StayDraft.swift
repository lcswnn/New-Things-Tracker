import Foundation
import CoreLocation

// Output of Stage 2 clustering, before it becomes a persisted Stay. `visitSignals` carries only
// the .visit-kind evidence (the only kind ever persisted as PresenceSignal — see FirstsSchema.swift);
// photo evidence is folded into `photoLocalIdentifiers` and never persisted as its own row.
nonisolated struct StayDraft: Sendable, Equatable {
    var startDate: Date
    var endDate: Date
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var photoLocalIdentifiers: [String]
    var visitSignals: [PresenceSignalDraft]
    var medianImpliedSpeedKmh: Double
    var isDiscarded: Bool
    var discardReason: String?

    var centroid: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var hasVisitEvidence: Bool { !visitSignals.isEmpty }

    // A valid (non-distantPast/distantFuture) arrival+departure pair, if any visit in this stay has one.
    var visitDwellSeconds: TimeInterval? {
        visitSignals
            .compactMap { signal -> TimeInterval? in
                guard let end = signal.endTimestamp,
                      signal.timestamp != .distantPast, end != .distantFuture else { return nil }
                return end.timeIntervalSince(signal.timestamp)
            }
            .max()
    }
}
