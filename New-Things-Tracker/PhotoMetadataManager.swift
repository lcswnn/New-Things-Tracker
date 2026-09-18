import Foundation
import Combine
import MapKit
import Photos
import CoreLocation

struct PhotoMetadataItem: Identifiable {
    let id: String                          // PHAsset.localIdentifier
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D? // nil when camera location was disabled
}

// A group of photos taken the same calendar day within `radiusMeters` of each other.
struct PhotoCluster: Identifiable {
    let id = UUID()
    private(set) var photos: [PhotoMetadataItem]
    private(set) var centroid: CLLocationCoordinate2D
    let day: Date
    var placeName: String?
    private(set) var latestTimestamp: Date
    var count: Int { photos.count }

    init(seed: PhotoMetadataItem) {
        photos          = [seed]
        centroid        = seed.coordinate!
        day             = Calendar.current.startOfDay(for: seed.timestamp)
        latestTimestamp = seed.timestamp
    }

    mutating func absorb(_ item: PhotoMetadataItem) {
        guard let coord = item.coordinate else { return }
        let n = Double(photos.count)
        centroid = CLLocationCoordinate2D(
            latitude:  (centroid.latitude  * n + coord.latitude)  / (n + 1),
            longitude: (centroid.longitude * n + coord.longitude) / (n + 1)
        )
        photos.append(item)
        if item.timestamp > latestTimestamp { latestTimestamp = item.timestamp }
    }
}

// A unique place — earliest day-cluster at this location, de-duplicated across all days.
struct PlaceCandidate: Identifiable {
    let id = UUID()
    let firstVisitDate: Date              // calendar day of the first photo at this place
    var centroid: CLLocationCoordinate2D  // running average of all visit centroids
    var placeName: String?                // filled asynchronously by geocoding
    var visitDates: [Date]                // one per day-cluster that matched this place
    var totalPhotoCount: Int
    var photoLocalIDs: [String]           // PHAsset localIdentifiers across all visits
    var visitCount: Int { visitDates.count }
}

class PhotoMetadataManager: ObservableObject {

    @Published var items:             [PhotoMetadataItem] = []
    @Published var clusters:          [PhotoCluster]      = []   // per-day, home-filtered
    @Published var placeCandidates:   [PlaceCandidate]    = []   // cross-day unique places
    @Published var isGeocodingPlaces: Bool                = false
    @Published var log:               [String]            = []

    var clusterRadius: Double = 150   // meters — within-day grouping AND cross-day de-dup
    var fetchDays:     Int    = 180

    // Reads home coordinate saved by ProfileViewController → UserDefaults.
    private var homeCoordinate: CLLocationCoordinate2D? {
        let lat = UserDefaults.standard.double(forKey: "homeLatitude")
        let lon = UserDefaults.standard.double(forKey: "homeLongitude")
        guard lat != 0.0 || lon != 0.0 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    private let homeExclusionRadius: Double = 300   // meters

    // MARK: - Entry point

    func requestPermissionAndFetch() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        appendLog("Current photo authorization: \(describe(status))")
        switch status {
        case .authorized, .limited:
            if status == .limited { appendLog("⚠️ LIMITED access — only user-selected photos visible.") }
            fetchMetadata()
        case .notDetermined:
            appendLog("Requesting photo library access…")
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                DispatchQueue.main.async {
                    self?.appendLog("Auth result: \(self?.describe(newStatus) ?? "")")
                    switch newStatus {
                    case .authorized, .limited:
                        if newStatus == .limited { self?.appendLog("⚠️ LIMITED access granted.") }
                        self?.fetchMetadata()
                    case .denied, .restricted:
                        self?.appendLog("⚠️ Denied. Go to Settings > Privacy > Photos.")
                    default: break
                    }
                }
            }
        case .denied, .restricted:
            appendLog("⚠️ Denied. Go to Settings > Privacy > Photos.")
        @unknown default:
            appendLog("Unknown status — attempting fetch anyway.")
            fetchMetadata()
        }
    }

    // MARK: - Fetch

    private func fetchMetadata() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -fetchDays, to: Date()) ?? Date()
        appendLog("Fetching camera photos (last \(fetchDays) days, screenshots excluded)…")

        DispatchQueue.global(qos: .userInitiated).async {
            let opts = PHFetchOptions()
            opts.predicate = NSPredicate(format: "creationDate >= %@", cutoff as NSDate)
            opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let assets = PHAsset.fetchAssets(with: .image, options: opts)

            var results: [PhotoMetadataItem] = []
            var skippedScreenshots = 0
            var withLocation = 0

            assets.enumerateObjects { asset, _, _ in
                if asset.mediaSubtypes.contains(.photoScreenshot) {
                    skippedScreenshots += 1
                    return
                }
                guard let date = asset.creationDate else { return }
                let coord = asset.location?.coordinate
                if coord != nil { withLocation += 1 }
                results.append(PhotoMetadataItem(
                    id: asset.localIdentifier,
                    timestamp: date,
                    coordinate: coord
                ))
            }

            let home       = self.homeCoordinate
            let allClusters = self.buildClusters(from: results, radiusMeters: self.clusterRadius)
            let filtered    = self.filterHome(from: allClusters, home: home, radius: self.homeExclusionRadius)
            let candidates  = self.buildPlaceCandidates(from: filtered)
            let excluded    = allClusters.count - filtered.count

            DispatchQueue.main.async {
                self.items           = results
                self.clusters        = filtered
                self.placeCandidates = candidates
                self.appendLog("✅ \(results.count) camera photos (\(skippedScreenshots) screenshots dropped), \(withLocation) have GPS.")
                if withLocation == 0 && !results.isEmpty {
                    self.appendLog("   0 GPS hits — check Settings > Privacy > Location Services > Camera.")
                }
                if home != nil {
                    self.appendLog("🏠 Home filter: \(excluded) day-cluster\(excluded == 1 ? "" : "s") excluded within \(Int(self.homeExclusionRadius))m.")
                }
                self.appendLog("📍 \(filtered.count) day-clusters → \(candidates.count) unique place\(candidates.count == 1 ? "" : "s") — geocoding…")
                Task { await self.geocodePlaceCandidates() }
            }
        }
    }

    // MARK: - Session-based clustering

    // Greedy single-pass: assign each GPS photo to the nearest open session cluster
    // if it falls within a 2-hour gap AND within sessionRadius meters of the centroid.
    // This groups photos taken at different spots of the same large venue (lake, park)
    // into one cluster instead of splitting them by precise location.
    private func buildClusters(from items: [PhotoMetadataItem], radiusMeters: Double) -> [PhotoCluster] {
        let sessionWindow: TimeInterval = 6 * 60 * 60  // 6-hour gap → new session
        let sessionRadius: Double       = 1_500        // 1.5 km — same venue complex (stadium + lot, large park)
        var clusters: [PhotoCluster] = []

        let geoItems = items
            .filter { $0.coordinate != nil }
            .sorted { $0.timestamp < $1.timestamp }

        for item in geoItems {
            guard let coord = item.coordinate else { continue }
            let itemLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)

            var bestIdx: Int?
            var bestDist = Double.infinity

            for (i, cluster) in clusters.enumerated() {
                let gap = item.timestamp.timeIntervalSince(cluster.latestTimestamp)
                guard gap <= sessionWindow else { continue }  // session expired
                let centerLoc = CLLocation(latitude: cluster.centroid.latitude,
                                           longitude: cluster.centroid.longitude)
                let dist = centerLoc.distance(from: itemLoc)
                if dist <= sessionRadius && dist < bestDist {
                    bestDist = dist
                    bestIdx  = i
                }
            }

            if let idx = bestIdx {
                clusters[idx].absorb(item)
            } else {
                clusters.append(PhotoCluster(seed: item))
            }
        }

        return clusters.sorted { $0.day > $1.day }
    }

    // MARK: - Home filtering

    private func filterHome(from clusters: [PhotoCluster], home: CLLocationCoordinate2D?, radius: Double) -> [PhotoCluster] {
        guard let home else { return clusters }
        let homeLoc = CLLocation(latitude: home.latitude, longitude: home.longitude)
        return clusters.filter { cluster in
            let loc = CLLocation(latitude: cluster.centroid.latitude, longitude: cluster.centroid.longitude)
            return loc.distance(from: homeLoc) > radius
        }
    }

    // MARK: - Cross-day de-duplication

    // Groups per-day clusters within `clusterRadius` of each other across ALL days.
    // The earliest cluster day becomes the "first visit date" for that place.
    private func buildPlaceCandidates(from clusters: [PhotoCluster]) -> [PlaceCandidate] {
        let sorted = clusters.sorted { $0.day < $1.day }   // oldest first → correct firstVisitDate
        var candidates: [PlaceCandidate] = []

        for cluster in sorted {
            let clusterLoc = CLLocation(latitude: cluster.centroid.latitude,
                                        longitude: cluster.centroid.longitude)

            if let idx = candidates.indices.first(where: { i in
                let loc = CLLocation(latitude: candidates[i].centroid.latitude,
                                     longitude: candidates[i].centroid.longitude)
                return loc.distance(from: clusterLoc) <= clusterRadius
            }) {
                candidates[idx].visitDates.append(cluster.day)
                candidates[idx].totalPhotoCount += cluster.count
                candidates[idx].photoLocalIDs   += cluster.photos.map { $0.id }
                let n = Double(candidates[idx].visitDates.count)
                candidates[idx].centroid = CLLocationCoordinate2D(
                    latitude:  (candidates[idx].centroid.latitude  * (n-1) + cluster.centroid.latitude)  / n,
                    longitude: (candidates[idx].centroid.longitude * (n-1) + cluster.centroid.longitude) / n
                )
            } else {
                candidates.append(PlaceCandidate(
                    firstVisitDate: cluster.day,
                    centroid: cluster.centroid,
                    placeName: nil,
                    visitDates: [cluster.day],
                    totalPhotoCount: cluster.count,
                    photoLocalIDs: cluster.photos.map { $0.id }
                ))
            }
        }

        return candidates.sorted { $0.firstVisitDate > $1.firstVisitDate }
    }

    // MARK: - Geocoding

    // Geocodes unique place candidates, using a UserDefaults cache keyed on a ~100m
    // grid cell so the same place is never re-geocoded across app launches.
    // Live requests are throttled to one every 1.3 s to stay under Apple's 50/60s burst limit.
    @MainActor
    private func geocodePlaceCandidates() async {
        guard !placeCandidates.isEmpty else { return }
        isGeocodingPlaces = true
        var liveCount = 0

        for i in placeCandidates.indices {
            let coord    = placeCandidates[i].centroid
            let cacheKey = geocodeCacheKey(coord)

            if let cached = UserDefaults.standard.string(forKey: cacheKey) {
                placeCandidates[i].placeName = cached
                continue
            }

            if liveCount > 0 {
                try? await Task.sleep(for: .milliseconds(1300))
            }
            liveCount += 1

            let name = await resolveNameForCoordinate(coord)
            placeCandidates[i].placeName = name
            UserDefaults.standard.set(name, forKey: cacheKey)
        }

        isGeocodingPlaces = false
        let cacheHits = placeCandidates.count - liveCount
        appendLog("✅ \(placeCandidates.count) place\(placeCandidates.count == 1 ? "" : "s") geocoded — \(liveCount) live, \(cacheHits) from cache.")
    }

    // Tries a POI search first so named venues (restaurants, lakes, parks) show their
    // real name rather than a street address. Falls back to reverse geocoding if no
    // named POI is found within 100 m of the cluster centroid.
    private func resolveNameForCoordinate(_ coord: CLLocationCoordinate2D) async -> String {
        let poiRequest = MKLocalPointsOfInterestRequest(center: coord, radius: 100)
        let poiSearch  = MKLocalSearch(request: poiRequest)
        if let response = try? await poiSearch.start(),
           let poiName  = response.mapItems.first?.name, !poiName.isEmpty {
            return poiName
        }

        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        if let request = MKReverseGeocodingRequest(location: loc),
           let mapItem = (try? await request.mapItems)?.first {
            return mapItem.name
                ?? mapItem.address?.shortAddress
                ?? mapItem.addressRepresentations?.cityName
                ?? "Unknown"
        }

        return String(format: "(%.4f, %.4f)", coord.latitude, coord.longitude)
    }

    // ~100 m grid cell key — close enough that the same venue always maps to the same key
    // even as the running-average centroid drifts slightly between visits.
    private func geocodeCacheKey(_ coord: CLLocationCoordinate2D) -> String {
        "geocache_\(String(format: "%.3f", coord.latitude))_\(String(format: "%.3f", coord.longitude))"
    }

    // MARK: - Helpers

    private func appendLog(_ msg: String) {
        DispatchQueue.main.async { self.log.append("[\(self.hms())] \(msg)") }
    }

    private func hms() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: Date())
    }

    private func describe(_ s: PHAuthorizationStatus) -> String {
        switch s {
        case .notDetermined: return "notDetermined"
        case .restricted:    return "restricted"
        case .denied:        return "denied"
        case .authorized:    return "authorized (full)"
        case .limited:       return "limited (subset)"
        @unknown default:    return "unknown(\(s.rawValue))"
        }
    }
}
