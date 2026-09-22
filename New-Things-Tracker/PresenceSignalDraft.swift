import Foundation
import CoreLocation

// Unlike the persisted SignalSourceKind (which only ever stores .visit — see FirstsSchema.swift),
// clustering needs to see photo evidence too, so this draft-level kind has both cases.
nonisolated enum DraftSignalKind: String, Sendable, Equatable {
    case photo
    case visit
}

// A single piece of evidence (one photo, or one CLVisit) flowing into Stage 2 clustering, before
// anything is written to the store. Pure value type so clustering/scoring stay unit-testable.
nonisolated struct PresenceSignalDraft: Sendable, Equatable {
    var kind: DraftSignalKind
    var timestamp: Date
    var endTimestamp: Date?          // CLVisit departure; nil for photos and open-ended visits
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var assetLocalIdentifier: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
