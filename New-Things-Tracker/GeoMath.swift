import CoreLocation

// Small shared geometry helpers used by both Stage 2 (clustering) and Stage 3 (POI scoring).
nonisolated enum GeoMath {
    static func distanceMeters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
