import Foundation
import CoreLocation

// Fixed-response PlaceLookup for exercising Stage 3 without MapKit or CLGeocoder.
nonisolated struct StubPlaceLookup: PlaceLookup {
    var candidates: [POICandidateDraft] = []
    var reverseGeocodeResult: ReverseGeocodeResult = .empty

    func nearbyCandidates(center: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [POICandidateDraft] {
        candidates
    }

    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> ReverseGeocodeResult {
        reverseGeocodeResult
    }
}
