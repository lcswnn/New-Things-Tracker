import Foundation
import CoreLocation

// The importer's real PlaceLookup: POI candidates always come from MapKit; the coarse hierarchy
// (neighborhood/region/areaOfInterest/water/residential) always comes from the CLGeocoder-backed
// LegacyGeocoderLookup, since those fields don't exist on the modern MapKit reverse-geocoding API.
nonisolated struct CompositePlaceLookup: PlaceLookup {
    let poiSource: any PlaceLookup
    let geocoderSource: any PlaceLookup

    init(poiSource: any PlaceLookup = MapKitPlaceLookup(), geocoderSource: any PlaceLookup = LegacyGeocoderLookup()) {
        self.poiSource = poiSource
        self.geocoderSource = geocoderSource
    }

    func nearbyCandidates(center: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [POICandidateDraft] {
        try await poiSource.nearbyCandidates(center: center, radiusMeters: radiusMeters)
    }

    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> ReverseGeocodeResult {
        try await geocoderSource.reverseGeocode(coordinate)
    }
}
