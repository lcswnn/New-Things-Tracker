import Foundation
import CoreLocation

// Coarse hierarchy for a coordinate. Only `city` and `country` are obtainable from the modern,
// non-deprecated MapKit API (MKAddressRepresentations) — everything else here (region/state,
// neighborhood, areaOfInterestName, residential-address detection, water names) only exists via
// the deprecated CLGeocoder/CLPlacemark path. See LegacyGeocoderLookup.
nonisolated struct ReverseGeocodeResult: Sendable, Equatable {
    var city: String?
    var region: String?
    var country: String?
    var neighborhood: String?
    var areaOfInterestName: String?
    var isResidentialAddress: Bool
    var streetAddress: String?
    var waterName: String?

    static let empty = ReverseGeocodeResult(
        city: nil, region: nil, country: nil, neighborhood: nil,
        areaOfInterestName: nil, isResidentialAddress: false, streetAddress: nil, waterName: nil
    )
}

// Stage 3's seam onto MapKit/geocoding — lets the scorer be tested against StubPlaceLookup and
// keeps MapKitPlaceLookup and LegacyGeocoderLookup swappable/combinable by the importer.
protocol PlaceLookup: Sendable {
    func nearbyCandidates(center: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [POICandidateDraft]
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> ReverseGeocodeResult
}
