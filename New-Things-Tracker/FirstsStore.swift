import Foundation
import SwiftData
import Combine
import CoreLocation
import MapKit

// UI-facing read layer, mirroring the shape of the PhotoMetadataManager it replaces (an
// ObservableObject with @Published arrays) so ViewController's existing Combine wiring needs
// minimal changes. Reads container.mainContext directly; writes only ever happen through
// FirstsImporter on its own actor.
@MainActor
final class FirstsStore: ObservableObject {
    @Published private(set) var places: [PlaceSummary] = []
    @Published private(set) var pendingReview: [ReviewCandidate] = []
    @Published private(set) var isImporting = false
    @Published private(set) var log: [String] = []

    private let container: ModelContainer
    private let importer: FirstsImporter

    init(container: ModelContainer) {
        self.container = container
        self.importer = FirstsImporter(modelContainer: container)
        refresh()
    }

    func runBackfill() async {
        guard !isImporting else { return }
        isImporting = true
        appendLog("Starting Firsts backfill…")
        let summary = await importer.runFullBackfill()
        refresh()
        isImporting = false
        appendLog("Backfill complete — \(summary.stayCount) stays, \(summary.resolvedPlaceCount) resolved, "
            + "\(summary.needsConfirmationCount) need confirmation, \(summary.newFirstsCount) new firsts.")
    }

    // Persists a live CLVisit immediately; picked up by the next backfill run (Phase 6 schedules
    // that automatically via BGTaskScheduler).
    func recordVisit(arrivalDate: Date, departureDate: Date?, coordinate: CLLocationCoordinate2D, horizontalAccuracy: Double) {
        let draft = PresenceSignalDraft(
            kind: .visit, timestamp: arrivalDate, endTimestamp: departureDate,
            latitude: coordinate.latitude, longitude: coordinate.longitude,
            horizontalAccuracy: horizontalAccuracy, assetLocalIdentifier: nil
        )
        Task { [importer] in try? await importer.recordVisit(draft) }
    }

    func recordVisit(_ visit: LocationVisit) {
        recordVisit(
            arrivalDate: visit.arrivalDate, departureDate: visit.departureDate,
            coordinate: visit.coordinate, horizontalAccuracy: visit.horizontalAccuracy
        )
    }

    // MARK: - Review actions

    func confirmTopCandidate(forStayID id: PersistentIdentifier) async {
        try? await importer.confirmTopCandidate(stayID: id)
        refresh()
    }

    func discardStay(forStayID id: PersistentIdentifier) async {
        try? await importer.discardStay(stayID: id)
        refresh()
    }

    func applyCorrection(_ draft: CorrectionDraft) async {
        try? await importer.applyCorrection(draft)
        refresh()
    }

    // Candidates for the review sheet's "Merge into…" picker, nearest first.
    func nearbyPlaces(to coordinate: CLLocationCoordinate2D, excludingKey: String, limit: Int = 5) -> [PlaceSummary] {
        let allPlaces = (try? container.mainContext.fetch(FetchDescriptor<Place>())) ?? []
        return allPlaces
            .filter { $0.key != excludingKey }
            .sorted { GeoMath.distanceMeters($0.coordinate, coordinate) < GeoMath.distanceMeters($1.coordinate, coordinate) }
            .prefix(limit)
            .map(PlaceSummary.init)
    }

    func refresh() {
        let context = container.mainContext
        do {
            let allPlaces = try context.fetch(FetchDescriptor<Place>(sortBy: [SortDescriptor(\.firstSeenAt, order: .reverse)]))
            places = allPlaces
                .filter { $0.role == .none && !$0.firsts.isEmpty }
                .map(PlaceSummary.init)

            let needsConfirmation = ResolutionStatus.needsConfirmation
            let awaitingConfirmation = try context.fetch(FetchDescriptor<Stay>(
                predicate: #Predicate { $0.resolution == needsConfirmation }
            ))
            pendingReview = Array(
                awaitingConfirmation.sorted { $0.startDate > $1.startDate }.prefix(5)
            ).map(ReviewCandidate.init)
        } catch {
            appendLog("⚠️ Refresh failed: \(error.localizedDescription)")
        }
    }

    func place(for id: PersistentIdentifier) -> Place? {
        container.mainContext.model(for: id) as? Place
    }

    // Neighborhood/city/region/country Firsts, for the map tab — the place-level feed stays
    // place-only so a single trip doesn't stack four cards on top of each other.
    func coarseFirsts() -> [CoarseFirstSummary] {
        let placeLevel = FirstLevel.place
        let all = (try? container.mainContext.fetch(FetchDescriptor<First>(
            predicate: #Predicate { $0.level != placeLevel }
        ))) ?? []
        return all.map(CoarseFirstSummary.init)
    }

    private func appendLog(_ message: String) {
        log.append(message)
    }
}

// MARK: - View models

struct CoarseFirstSummary: Identifiable, Sendable {
    let id: PersistentIdentifier
    let title: String
    let level: FirstLevel
    let coordinate: CLLocationCoordinate2D

    init(first: First) {
        id = first.persistentModelID
        title = first.title
        level = first.level
        coordinate = CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
    }
}

// Mirrors the old PlaceCandidate's shape so downstream UI (PlaceDetailViewController,
// DiscoverViewController, ProfileViewController) changes minimally, but keyed on a real stable
// identity (PersistentIdentifier / Place.key) instead of a lossy 3-decimal centroid grid.
struct PlaceSummary: Identifiable, Sendable {
    let id: PersistentIdentifier
    let key: String
    let placeName: String
    let firstVisitDate: Date
    let visitCount: Int
    let totalPhotoCount: Int
    let photoLocalIDs: [String]
    let centroid: CLLocationCoordinate2D

    init(place: Place) {
        id = place.persistentModelID
        key = place.key
        placeName = place.displayName
        firstVisitDate = place.firstSeenAt
        visitCount = place.visitCount
        let allPhotoIDs = place.stays.flatMap(\.photoLocalIdentifiers)
        totalPhotoCount = allPhotoIDs.count
        photoLocalIDs = allPhotoIDs
        centroid = place.coordinate
    }
}

struct ReviewCandidate: Identifiable, Sendable {
    let id: PersistentIdentifier
    let placeName: String
    let firstVisitDate: Date
    let totalPhotoCount: Int
    let photoLocalIDs: [String]
    let centroid: CLLocationCoordinate2D
    let topCandidates: [CandidateOption]

    init(stay: Stay) {
        id = stay.persistentModelID
        let sorted = stay.candidates.sorted { $0.rank < $1.rank }
        placeName = sorted.first?.displayName ?? "Somewhere new"
        firstVisitDate = stay.startDate
        totalPhotoCount = stay.photoLocalIdentifiers.count
        photoLocalIDs = stay.photoLocalIdentifiers
        centroid = stay.centroid
        topCandidates = sorted.map(CandidateOption.init)
    }
}

// A scored POI option the review sheet can offer the user, or turn back into a POICandidateDraft
// to hand to FirstsImporter.applyCorrection.
struct CandidateOption: Identifiable, Sendable {
    let id: PersistentIdentifier
    let displayName: String
    let score: Double
    let mapKitIdentifier: String?
    let poiCategoryRaw: String?
    let latitude: Double
    let longitude: Double

    init(record: PlaceCandidateRecord) {
        id = record.persistentModelID
        displayName = record.displayName
        score = record.score
        mapKitIdentifier = record.mapKitIdentifier
        poiCategoryRaw = record.poiCategoryRaw
        latitude = record.latitude
        longitude = record.longitude
    }

    var asDraft: POICandidateDraft {
        let categoryGroup: PlaceCategoryGroup = poiCategoryRaw
            .map { POICategoryMap.group(for: MKPointOfInterestCategory(rawValue: $0)) } ?? .unknown
        return POICandidateDraft(
            displayName: displayName, mapKitIdentifier: mapKitIdentifier,
            categoryGroup: categoryGroup, poiCategoryRaw: poiCategoryRaw,
            latitude: latitude, longitude: longitude
        )
    }
}
