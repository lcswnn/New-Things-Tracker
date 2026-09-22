import Foundation
import CoreLocation
import MapKit

// The modern, non-deprecated PlaceLookup: MKLocalPointsOfInterestRequest for named-place candidates,
// MKReverseGeocodingRequest for coarse city/country. Never touches MKMapItem.placemark (hard
// deprecated ios(6.0, 26.0)) — location/address/addressRepresentations only.
nonisolated struct MapKitPlaceLookup: PlaceLookup {

    func nearbyCandidates(center: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [POICandidateDraft] {
        // MKLocalPointsOfInterestRequest silently clamps to maxRadius rather than rejecting the
        // request, so clamp explicitly here instead of letting a caller's radius quietly lie.
        let clampedRadius = min(radiusMeters, MKLocalPointsOfInterestRequest.maxRadius)
        let request = MKLocalPointsOfInterestRequest(center: center, radius: clampedRadius)
        let response = try await MKLocalSearch(request: request).start()

        return response.mapItems.compactMap { item in
            guard let name = item.name, !name.isEmpty else { return nil }
            let category = item.pointOfInterestCategory
            return POICandidateDraft(
                displayName: name,
                mapKitIdentifier: item.identifier?.rawValue,
                categoryGroup: category.map(POICategoryMap.group(for:)) ?? .unknown,
                poiCategoryRaw: category?.rawValue,
                latitude: item.location.coordinate.latitude,
                longitude: item.location.coordinate.longitude
            )
        }
    }

    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> ReverseGeocodeResult {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return .empty }
        let items = try await request.mapItems
        guard let representations = items.first?.addressRepresentations else { return .empty }
        return ReverseGeocodeResult(
            city: representations.cityName,
            region: nil,
            country: representations.regionName,
            neighborhood: nil,
            areaOfInterestName: nil,
            isResidentialAddress: false,
            streetAddress: nil,
            waterName: nil
        )
    }
}
