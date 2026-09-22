import Foundation
import CoreLocation

// A named-place candidate returned by a PlaceLookup, before it's scored or persisted. Codable so
// it can round-trip through GeoCacheEntry.payload.
nonisolated struct POICandidateDraft: Sendable, Equatable, Codable {
    var displayName: String
    var mapKitIdentifier: String?
    var categoryGroup: PlaceCategoryGroup
    var poiCategoryRaw: String?
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
