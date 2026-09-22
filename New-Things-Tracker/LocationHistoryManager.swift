import Foundation
import Combine
import CoreLocation

struct LocationVisit {
    let arrivalDate: Date       // .distantPast means iOS doesn't know exact arrival time
    let departureDate: Date?    // nil means still at this location (CLVisit reported .distantFuture)
    let coordinate: CLLocationCoordinate2D
    let horizontalAccuracy: Double
}

class LocationHistoryManager: NSObject, ObservableObject {

    @Published var visits: [LocationVisit] = []
    @Published var log: [String] = []

    // Set by ViewController to persist every CLVisit into the Firsts store as it arrives — visit
    // data is the one unrecoverable log in the schema, so it's written immediately, not batched.
    var onVisit: ((LocationVisit) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestPermissionAndStart() {
        let status = manager.authorizationStatus
        appendLog("Current authorization: \(describe(status))")
        switch status {
        case .notDetermined:
            appendLog("Requesting 'When In Use'…")
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            appendLog("Have 'When In Use' — requesting upgrade to 'Always'…")
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            startMonitoring()
        case .denied, .restricted:
            appendLog("⚠️ Denied. Go to Settings > Privacy > Location Services.")
        @unknown default:
            appendLog("Unknown status (\(status.rawValue)).")
        }
    }

    private func startMonitoring() {
        manager.startMonitoringVisits()
        manager.startMonitoringSignificantLocationChanges()
        appendLog("✅ Visit monitoring + significant-location-change monitoring started.")
        appendLog("   Stored visits so far: \(visits.count) (zero is expected on first launch — iOS fires CLVisit events only after you arrive somewhere new).")
    }

    // MARK: - Helpers

    private func appendLog(_ msg: String) {
        DispatchQueue.main.async {
            self.log.append("[\(self.hms())] \(msg)")
        }
    }

    private func hms() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }

    private func describe(_ s: CLAuthorizationStatus) -> String {
        switch s {
        case .notDetermined:      return "notDetermined"
        case .restricted:         return "restricted"
        case .denied:             return "denied"
        case .authorizedAlways:   return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default:         return "unknown(\(s.rawValue))"
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationHistoryManager: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        appendLog("Auth changed → \(describe(status))")
        switch status {
        case .authorizedAlways:
            startMonitoring()
        case .authorizedWhenInUse:
            // Present the second "upgrade to Always" system dialog
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            appendLog("⚠️ Monitoring unavailable — location access denied.")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let depart: Date? = visit.departureDate == .distantFuture ? nil : visit.departureDate
        let item = LocationVisit(
            arrivalDate: visit.arrivalDate,
            departureDate: depart,
            coordinate: visit.coordinate,
            horizontalAccuracy: visit.horizontalAccuracy
        )
        DispatchQueue.main.async {
            self.visits.append(item)
            self.onVisit?(item)
        }

        let arrStr = visit.arrivalDate == .distantPast
            ? "unknown arrival"
            : ISO8601DateFormatter().string(from: visit.arrivalDate)
        let depStr = depart.map { ISO8601DateFormatter().string(from: $0) } ?? "still here"
        appendLog("📍 VISIT  lat=\(fmt(visit.coordinate.latitude))  lon=\(fmt(visit.coordinate.longitude))  acc=\(Int(visit.horizontalAccuracy))m")
        appendLog("         arr=\(arrStr)  dep=\(depStr)")
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        appendLog("📡 SIG-CHANGE  lat=\(fmt(loc.coordinate.latitude))  lon=\(fmt(loc.coordinate.longitude))  acc=\(Int(loc.horizontalAccuracy))m")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        appendLog("❌ \(error.localizedDescription)")
    }

    private func fmt(_ d: Double) -> String { String(format: "%.5f", d) }
}
