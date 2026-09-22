import CoreLocation

// Standard base32 geohash encoding. Precision 7 (~153m x 153m cells) is what GeoCacheEntry and
// Place key on — see the note in FirstsSchema.swift about assigning keys AFTER spatial merging,
// since a 40m merge radius is narrower than a geohash7 cell and two nearby points can straddle a
// cell boundary.
nonisolated enum Geohash {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    static func encode(latitude: Double, longitude: Double, precision: Int = 7) -> String {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var result = ""
        var bit = 0
        var bitCount = 0
        var isEven = true

        while result.count < precision {
            if isEven {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude >= mid { bit = (bit << 1) | 1; lonRange.0 = mid } else { bit <<= 1; lonRange.1 = mid }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude >= mid { bit = (bit << 1) | 1; latRange.0 = mid } else { bit <<= 1; latRange.1 = mid }
            }
            isEven.toggle()
            bitCount += 1
            if bitCount == 5 {
                result.append(base32[bit])
                bit = 0
                bitCount = 0
            }
        }
        return result
    }

    static func encode(_ coordinate: CLLocationCoordinate2D, precision: Int = 7) -> String {
        encode(latitude: coordinate.latitude, longitude: coordinate.longitude, precision: precision)
    }
}
