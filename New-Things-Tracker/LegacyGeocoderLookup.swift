import Foundation
import CoreLocation

// The ONLY file in this project allowed to reference CLGeocoder or CLPlacemark. Both are
// deprecated on this iOS 26.5+ target (CLGeocoder is hard-deprecated ios(5.0, 26.0)), but they
// remain the sole source of neighborhood (subLocality), state (administrativeArea), areasOfInterest,
// and inland-water/ocean names — none of which exist on the modern MKAddressRepresentations API.
// Quarantining every reference here confines the deprecation warning to one place and means the
// day Apple removes CLGeocoder outright, only this file needs to change.
//
// Has no POI search of its own — nearbyCandidates always returns empty; candidates come from
// MapKitPlaceLookup. This type exists purely to supply reverseGeocode's coarse hierarchy fields.
nonisolated struct LegacyGeocoderLookup: PlaceLookup {

    func nearbyCandidates(center: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [POICandidateDraft] {
        []
    }

    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> ReverseGeocodeResult {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try await CLGeocoder().reverseGeocodeLocation(location).first else {
            return .empty
        }
        let streetAddress = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")

        return ReverseGeocodeResult(
            city: placemark.locality,
            region: placemark.administrativeArea,
            country: placemark.country,
            neighborhood: placemark.subLocality,
            areaOfInterestName: placemark.areasOfInterest?.first,
            isResidentialAddress: placemark.subThoroughfare != nil && placemark.thoroughfare != nil,
            streetAddress: streetAddress.isEmpty ? nil : streetAddress,
            waterName: placemark.inlandWater ?? placemark.ocean
        )
    }
}
