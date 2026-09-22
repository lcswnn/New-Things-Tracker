import Foundation
import SwiftData
import CoreLocation
import MapKit

nonisolated struct ImportSummary: Sendable, Equatable {
    var stayCount: Int
    var resolvedPlaceCount: Int
    var needsConfirmationCount: Int
    var discardedCount: Int
    var newFirstsCount: Int

    static let empty = ImportSummary(stayCount: 0, resolvedPlaceCount: 0, needsConfirmationCount: 0, discardedCount: 0, newFirstsCount: 0)
}

// MARK: - PlaceReviewSheet actions

nonisolated enum CorrectionAction: Sendable {
    case selectCandidate(POICandidateDraft)
    case rename(String)
    case notAPlace
    case markHome
    case markWork
    case markPrivate
    case merge(intoPlaceKey: String)
}

nonisolated struct CorrectionDraft: Sendable {
    var stayID: PersistentIdentifier
    var action: CorrectionAction
}

extension PlaceCandidateRecord {
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

// Runs the full Stage 1-5 pipeline on its own actor so photo enumeration, MapKit/geocoder calls,
// and SwiftData writes never touch the main actor. Every import run wipes and rebuilds Stay +
// PlaceCandidateRecord (100% re-derivable from PresenceSignal + a fresh PHAsset fetch) but never
// touches PresenceSignal (the one unrecoverable log), Place identity/history, or UserCorrection.
@ModelActor
actor FirstsImporter {
    private let placeLookup: any PlaceLookup = CompositePlaceLookup()
    private let tuning: PipelineTuning = .default

    // MARK: - Entry points

    func runFullBackfill(now: Date = .now, calendar: Calendar = .current) async -> ImportSummary {
        do {
            let photoSignals = PhotoLibrarySource.fetchPhotoSignals()
            let visitSignals = try fetchPersistedVisitDrafts()
            let stayDrafts = StayBuilder.buildStays(from: photoSignals + visitSignals, tuning: tuning)

            // Snapshot before wiping: Stay is fully re-derived every run, so without this, a user's
            // confirmation or Phase 5 correction would be silently re-resolved on the very next run.
            let reviewedSnapshots = try snapshotUserReviewedStays()
            try wipeDerivedStayData()

            var resolvedPairs: [(Stay, Place?)] = []
            for draft in stayDrafts where !draft.isDiscarded {
                let stay = makeStay(from: draft)
                modelContext.insert(stay)

                if let snapshot = reviewedSnapshots.first(where: { $0.startDate == draft.startDate && $0.endDate == draft.endDate }) {
                    stay.resolution = snapshot.resolution
                    stay.confidence = snapshot.confidence
                    stay.qualifiesForFirst = snapshot.qualifiesForFirst
                    stay.userReviewed = true
                    let place = try snapshot.placeKey.flatMap { try findPlace(byKey: $0) }
                    if let place { attach(stay: stay, to: place) }
                    resolvedPairs.append((stay, place))
                    continue
                }

                let place = try await resolve(stay: stay, draft: draft, now: now)
                resolvedPairs.append((stay, place))
            }
            try modelContext.save()

            recomputeVisitCounts(for: resolvedPairs)
            try classifyHomeAndWork(resolvedPairs, calendar: calendar)
            try applyHomeWorkCorrections()
            try modelContext.save()

            let newFirsts = try createFirsts(from: resolvedPairs)
            let newCoarseFirsts = try createCoarseFirsts(from: resolvedPairs)
            try modelContext.save()

            try GeoCache.evictExpired(in: modelContext, now: now)
            try modelContext.save()

            return ImportSummary(
                stayCount: resolvedPairs.count,
                resolvedPlaceCount: resolvedPairs.filter { $0.0.resolution == .resolved }.count,
                needsConfirmationCount: resolvedPairs.filter { $0.0.resolution == .needsConfirmation }.count,
                discardedCount: stayDrafts.count - resolvedPairs.count,
                newFirstsCount: newFirsts + newCoarseFirsts
            )
        } catch {
            return .empty
        }
    }

    private struct ReviewedStaySnapshot {
        var startDate: Date
        var endDate: Date
        var resolution: ResolutionStatus
        var confidence: Double
        var qualifiesForFirst: Bool
        var placeKey: String?
    }

    private func snapshotUserReviewedStays() throws -> [ReviewedStaySnapshot] {
        let reviewed = true
        return try modelContext.fetch(FetchDescriptor<Stay>(predicate: #Predicate { $0.userReviewed == reviewed }))
            .map {
                ReviewedStaySnapshot(
                    startDate: $0.startDate, endDate: $0.endDate, resolution: $0.resolution,
                    confidence: $0.confidence, qualifiesForFirst: $0.qualifiesForFirst, placeKey: $0.place?.key
                )
            }
    }

    // Persists a live CLVisit immediately (visit data is unrecoverable if dropped), without
    // re-running the full pipeline — that happens on the next full backfill. Phase 6 wires this to
    // BGTaskScheduler; for now a fresh backfill run picks it up.
    func recordVisit(_ draft: PresenceSignalDraft) throws {
        let signal = PresenceSignal(
            sourceKind: .visit, timestamp: draft.timestamp, endTimestamp: draft.endTimestamp,
            latitude: draft.latitude, longitude: draft.longitude, horizontalAccuracy: draft.horizontalAccuracy
        )
        modelContext.insert(signal)
        try modelContext.save()
    }

    // MARK: - Review actions

    // "Yes" on the review carousel: accept the top-scored candidate outright.
    func confirmTopCandidate(stayID: PersistentIdentifier, now: Date = .now) async throws {
        guard let stay = modelContext.model(for: stayID) as? Stay else { return }
        stay.userReviewed = true
        guard let top = stay.candidates.min(by: { $0.rank < $1.rank }) else {
            stay.resolution = .discarded
            try modelContext.save()
            return
        }
        try await confirm(stay: stay, with: top.asDraft, now: now)
        try modelContext.save()
    }

    // "No" on the review carousel: reject outright.
    func discardStay(stayID: PersistentIdentifier) async throws {
        guard let stay = modelContext.model(for: stayID) as? Stay else { return }
        stay.resolution = .discarded
        stay.userReviewed = true
        try modelContext.save()
    }

    // The PlaceReviewSheet's full action set: pick a specific candidate, rename, mark not-a-place,
    // mark home/work/private, or merge into an existing Place. Every branch is scoped to the one
    // affected Stay/Place — never a full pipeline re-run.
    func applyCorrection(_ draft: CorrectionDraft, now: Date = .now) async throws {
        guard let stay = modelContext.model(for: draft.stayID) as? Stay else { return }
        stay.userReviewed = true

        switch draft.action {
        case .selectCandidate(let candidate):
            try await confirm(stay: stay, with: candidate, now: now)

        case .rename(let newName):
            guard let place = stay.place else { return }
            place.displayName = newName
            place.userRenamed = true
            for first in place.firsts where first.level == .place { first.title = newName }
            modelContext.insert(UserCorrection(kind: .rename, placeKey: place.key, newName: newName))

        case .notAPlace:
            stay.resolution = .discarded
            stay.qualifiesForFirst = false
            stay.place = nil
            modelContext.insert(UserCorrection(kind: .notAPlace, placeKey: stayFallbackKey(stay)))

        case .markHome:
            try markRole(.home, for: stay)
        case .markWork:
            try markRole(.work, for: stay)
        case .markPrivate:
            try markRole(.privateResidence, for: stay)

        case .merge(let targetKey):
            try merge(stay: stay, intoPlaceKeyed: targetKey)
        }

        try modelContext.save()
    }

    // Shared by both the "Yes" shortcut and the review sheet's candidate picker.
    private func confirm(stay: Stay, with candidate: POICandidateDraft, now: Date) async throws {
        stay.confidence = max(stay.confidence, 0.9)
        stay.qualifiesForFirst = true
        let place = try await upsertPlace(for: candidate, stay: stay, now: now)
        stay.resolution = .confirmed
        recomputeVisitCounts(for: [(stay, place)])
        try createFirstIfEarliest(stay: stay, place: place)
    }

    private func markRole(_ role: PlaceRole, for stay: Stay) throws {
        guard let place = stay.place else { return }
        place.role = role
        for first in place.firsts where first.level == .place { modelContext.delete(first) }
        let kind: CorrectionKind = role == .home ? .markHome : (role == .work ? .markWork : .markPrivate)
        modelContext.insert(UserCorrection(kind: kind, placeKey: place.key))
    }

    private func merge(stay: Stay, intoPlaceKeyed targetKey: String) throws {
        guard let source = stay.place, let target = try findPlace(byKey: targetKey), source.key != target.key else { return }
        for movedStay in source.stays {
            attach(stay: movedStay, to: target)
            // Pin every moved stay, not just the one that triggered the merge — source is about to
            // be deleted, so without this, any of its OTHER stays would re-resolve against source's
            // original POI identity on the next backfill and silently undo the merge.
            movedStay.userReviewed = true
        }
        target.firstSeenAt = min(target.firstSeenAt, source.firstSeenAt)
        recomputeVisitCounts(for: target.stays.map { ($0, target) })
        modelContext.insert(UserCorrection(kind: .merge, placeKey: source.key, mergeTargetKey: target.key))
        modelContext.delete(source) // cascades to source's Firsts; the survivor keeps its own
    }

    private func createFirstIfEarliest(stay: Stay, place: Place) throws {
        guard place.role == .none else { return }
        if stay.startDate <= place.firstSeenAt {
            place.firstSeenAt = stay.startDate
        }
        guard !place.firsts.contains(where: { $0.level == .place }) else { return }
        modelContext.insert(First(
            level: .place, occurredAt: place.firstSeenAt, title: place.displayName,
            latitude: place.latitude, longitude: place.longitude, confidence: stay.confidence, place: place
        ))
    }

    // A "not a place" Stay has no Place to key a UserCorrection against, so this is a synthetic,
    // stable-per-stay key purely for the audit trail — it plays no role in the userReviewed
    // reattachment logic, which snapshots the Stay itself.
    private func stayFallbackKey(_ stay: Stay) -> String {
        "stay|\(stay.startDate.timeIntervalSince1970)|\(stay.endDate.timeIntervalSince1970)"
    }

    private func findPlace(byKey key: String) throws -> Place? {
        var descriptor = FetchDescriptor<Place>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Stage 1 (visits)

    private func fetchPersistedVisitDrafts() throws -> [PresenceSignalDraft] {
        try modelContext.fetch(FetchDescriptor<PresenceSignal>()).map {
            PresenceSignalDraft(
                kind: .visit, timestamp: $0.timestamp, endTimestamp: $0.endTimestamp,
                latitude: $0.latitude, longitude: $0.longitude,
                horizontalAccuracy: $0.horizontalAccuracy, assetLocalIdentifier: nil
            )
        }
    }

    // MARK: - Wipe derived data

    // Per-object delete, not a batch delete-by-predicate: SwiftData's batch delete operates
    // directly on the store and does NOT run delete rules, so it would leave PresenceSignal.stay
    // dangling and PlaceCandidateRecord orphaned instead of nullifying/cascading correctly.
    private func wipeDerivedStayData() throws {
        for stay in try modelContext.fetch(FetchDescriptor<Stay>()) {
            modelContext.delete(stay)
        }
        try modelContext.save()
    }

    private func makeStay(from draft: StayDraft) -> Stay {
        Stay(
            startDate: draft.startDate, endDate: draft.endDate,
            latitude: draft.latitude, longitude: draft.longitude, radiusMeters: draft.radiusMeters,
            photoLocalIdentifiers: draft.photoLocalIdentifiers,
            medianImpliedSpeedKmh: draft.medianImpliedSpeedKmh
        )
    }

    // MARK: - Stage 3 (resolution)

    private func resolve(stay: Stay, draft: StayDraft, now: Date) async throws -> Place? {
        let searchRadius = min(
            max(tuning.poiSearchRadiusMeters, 1.5 * max(draft.radiusMeters, 1)),
            tuning.maxPoiSearchRadiusMeters
        )
        let geohash7 = Geohash.encode(stay.centroid)

        let candidates: [POICandidateDraft]
        if let cached = try GeoCache.lookup(geohash7: geohash7, in: modelContext, now: now) {
            candidates = cached
        } else {
            candidates = (try? await placeLookup.nearbyCandidates(center: stay.centroid, radiusMeters: searchRadius)) ?? []
            try GeoCache.store(geohash7: geohash7, candidates: candidates, in: modelContext, now: now)
        }

        let scoringContext = PlaceScoringContext(
            centroid: stay.centroid,
            searchRadiusMeters: searchRadius,
            photoCount: draft.photoLocalIdentifiers.count,
            dwellMinutes: (draft.visitDwellSeconds ?? 0) / 60,
            hasVisit: draft.hasVisitEvidence
        )
        let resolution = PlaceScorer.resolve(candidates, against: scoringContext, tuning: tuning)
        stay.qualifiesForFirst = stayQualifiesForFirst(draft: draft, resolution: resolution)

        switch resolution {
        case .resolved(let scored):
            stay.resolution = .resolved
            stay.confidence = scored.score
            return try await upsertPlace(for: scored.candidate, stay: stay, now: now)

        case .needsConfirmation(let top):
            stay.resolution = .needsConfirmation
            stay.confidence = (top.first?.score ?? 0) * 0.7
            for (index, scored) in top.enumerated() {
                let record = PlaceCandidateRecord(
                    rank: index, score: scored.score, displayName: scored.candidate.displayName,
                    mapKitIdentifier: scored.candidate.mapKitIdentifier, poiCategoryRaw: scored.candidate.poiCategoryRaw,
                    latitude: scored.candidate.latitude, longitude: scored.candidate.longitude
                )
                record.stay = stay
                modelContext.insert(record)
            }
            return nil

        case .noMatch:
            return try await resolveFallback(stay: stay, draft: draft)
        }
    }

    // A visit-only Stay needs a valid >=10min dwell to qualify; if arrival/departure are unknown
    // (distantPast/distantFuture), fall back to requiring high resolution confidence instead.
    private func stayQualifiesForFirst(draft: StayDraft, resolution: PlaceResolution) -> Bool {
        if !draft.photoLocalIdentifiers.isEmpty { return true }
        if let dwell = draft.visitDwellSeconds { return dwell >= tuning.minVisitDwellSeconds }
        if draft.hasVisitEvidence, case .resolved(let scored) = resolution {
            return scored.score >= tuning.minConfidenceToAutoAccept
        }
        return false
    }

    // MARK: - Stage 3 fallback (no scored POI candidate)

    private func resolveFallback(stay: Stay, draft: StayDraft) async throws -> Place? {
        let geocode = (try? await placeLookup.reverseGeocode(stay.centroid)) ?? .empty

        if geocode.isResidentialAddress, let address = geocode.streetAddress {
            stay.resolution = .resolved
            stay.confidence = 0.4
            return try upsertFallbackPlace(displayName: address, categoryGroup: .unknown, role: .privateResidence,
                                            confidence: 0.4, stay: stay, geocode: geocode)
        }
        if let area = geocode.areaOfInterestName {
            stay.resolution = .resolved
            stay.confidence = 0.55
            return try upsertFallbackPlace(displayName: area, categoryGroup: .outdoors, role: .none,
                                            confidence: 0.55, stay: stay, geocode: geocode)
        }
        if let water = geocode.waterName {
            stay.resolution = .resolved
            stay.confidence = 0.5
            return try upsertFallbackPlace(displayName: water, categoryGroup: .outdoors, role: .none,
                                            confidence: 0.5, stay: stay, geocode: geocode)
        }

        stay.resolution = .discarded
        stay.confidence = 0
        return nil
    }

    // MARK: - Place upsert

    private func upsertPlace(for candidate: POICandidateDraft, stay: Stay, now: Date) async throws -> Place {
        let normalizedName = PlaceIdentity.normalize(candidate.displayName)

        if let existing = try findMergeCandidate(mapKitIdentifier: candidate.mapKitIdentifier,
                                                  normalizedName: normalizedName, near: stay.centroid) {
            if let mapKitIdentifier = candidate.mapKitIdentifier, existing.mapKitIdentifier != mapKitIdentifier,
               !existing.alternateIdentifiers.contains(mapKitIdentifier) {
                existing.alternateIdentifiers.append(mapKitIdentifier)
            }
            attach(stay: stay, to: existing)
            return existing
        }

        let geohash7 = Geohash.encode(stay.centroid)
        let key = PlaceIdentity.canonicalKey(mapKitIdentifier: candidate.mapKitIdentifier, normalizedName: normalizedName, geohash7: geohash7)
        let geocode = (try? await placeLookup.reverseGeocode(stay.centroid)) ?? .empty

        let place = Place(
            key: key, displayName: candidate.displayName, normalizedName: normalizedName, geohash7: geohash7,
            mapKitIdentifier: candidate.mapKitIdentifier, poiCategoryRaw: candidate.poiCategoryRaw,
            categoryGroup: candidate.categoryGroup, latitude: stay.centroid.latitude, longitude: stay.centroid.longitude,
            neighborhood: geocode.neighborhood, city: geocode.city, region: geocode.region, country: geocode.country,
            confidence: stay.confidence, firstSeenAt: stay.startDate, lastSeenAt: stay.endDate
        )
        modelContext.insert(place)
        attach(stay: stay, to: place)
        return place
    }

    private func upsertFallbackPlace(
        displayName: String, categoryGroup: PlaceCategoryGroup, role: PlaceRole,
        confidence: Double, stay: Stay, geocode: ReverseGeocodeResult
    ) throws -> Place {
        let normalizedName = PlaceIdentity.normalize(displayName)

        if let existing = try findMergeCandidate(mapKitIdentifier: nil, normalizedName: normalizedName, near: stay.centroid) {
            attach(stay: stay, to: existing)
            return existing
        }

        let geohash7 = Geohash.encode(stay.centroid)
        let key = PlaceIdentity.canonicalKey(mapKitIdentifier: nil, normalizedName: normalizedName, geohash7: geohash7)
        let place = Place(
            key: key, displayName: displayName, normalizedName: normalizedName, geohash7: geohash7,
            categoryGroup: categoryGroup, latitude: stay.centroid.latitude, longitude: stay.centroid.longitude,
            neighborhood: geocode.neighborhood, city: geocode.city, region: geocode.region, country: geocode.country,
            role: role, confidence: confidence, firstSeenAt: stay.startDate, lastSeenAt: stay.endDate
        )
        modelContext.insert(place)
        attach(stay: stay, to: place)
        return place
    }

    // 40m spatial merge + same normalized name, or a matching mapKitIdentifier/alternateIdentifiers.
    // Deliberately does NOT merge same-named places farther than mergeDistanceMeters apart, and
    // does NOT merge different-named places at the same address (e.g. "Central Park" and "Central
    // Park Zoo" stay distinct — each is a legitimate separate first).
    private func findMergeCandidate(mapKitIdentifier: String?, normalizedName: String, near coordinate: CLLocationCoordinate2D) throws -> Place? {
        if let mapKitIdentifier {
            let descriptor = FetchDescriptor<Place>(predicate: #Predicate { $0.mapKitIdentifier == mapKitIdentifier })
            if let match = try modelContext.fetch(descriptor).first { return match }
        }
        let descriptor = FetchDescriptor<Place>(predicate: #Predicate { $0.normalizedName == normalizedName })
        return try modelContext.fetch(descriptor)
            .first { GeoMath.distanceMeters($0.coordinate, coordinate) <= tuning.mergeDistanceMeters }
    }

    private func attach(stay: Stay, to place: Place) {
        stay.place = place
        place.firstSeenAt = min(place.firstSeenAt, stay.startDate)
        place.lastSeenAt = max(place.lastSeenAt, stay.endDate)
    }

    // Recomputed from the freshly-rebuilt `stays` relationship rather than incremented in attach(),
    // since Stay is wiped and rebuilt every run — an incrementing counter would double (then
    // triple, then...) every relaunch instead of reflecting the true current visit count.
    private func recomputeVisitCounts(for pairs: [(Stay, Place?)]) {
        var touchedPlaces: [String: Place] = [:]
        for (_, place) in pairs {
            if let place { touchedPlaces[place.key] = place }
        }
        for place in touchedPlaces.values {
            place.visitCount = place.stays.count
        }
    }

    // MARK: - Stage 4 (home/work)

    private func classifyHomeAndWork(_ pairs: [(Stay, Place?)], calendar: Calendar) throws {
        let windows = pairs.compactMap { stay, place -> StayTimeWindow? in
            guard let place else { return nil }
            return StayTimeWindow(placeKey: place.key, startDate: stay.startDate)
        }
        let classification = HomeWorkClassifier.classify(windows, tuning: tuning, calendar: calendar)

        let allPlaces = try modelContext.fetch(FetchDescriptor<Place>())
        for place in allPlaces where place.role == .home || place.role == .work {
            place.role = .none // may lose home/work status as more data arrives; recomputed fresh
        }
        if let homeKey = classification.homePlaceKey {
            allPlaces.first { $0.key == homeKey }?.role = .home
        }
        if let workKey = classification.workPlaceKey {
            allPlaces.first { $0.key == workKey }?.role = .work
        }
    }

    // Re-applies every user-authored home/work correction after Stage 4's automatic classification
    // resets .home/.work roles, so a correction from the review sheet — keyed on a real Place.key —
    // isn't silently undone on the very next run. Also handles LegacyMigration's coordinate-keyed
    // corrections (recorded before any Place existed), matching them to a real Place by proximity
    // and rewriting the key once matched, so that becomes a no-op on every subsequent run too.
    private func applyHomeWorkCorrections() throws {
        let corrections = try modelContext.fetch(FetchDescriptor<UserCorrection>())
            .filter { $0.kind == .markHome || $0.kind == .markWork }
        guard !corrections.isEmpty else { return }

        let places = try modelContext.fetch(FetchDescriptor<Place>())
        for correction in corrections {
            let matchedPlace: Place?
            if correction.placeKey.hasPrefix("legacy|") {
                matchedPlace = matchLegacyCoordinateKey(correction.placeKey, among: places)
                if let matchedPlace { correction.placeKey = matchedPlace.key }
            } else {
                matchedPlace = places.first { $0.key == correction.placeKey }
            }
            matchedPlace?.role = correction.kind == .markHome ? .home : .work
        }
    }

    private func matchLegacyCoordinateKey(_ key: String, among places: [Place]) -> Place? {
        let parts = key.split(separator: "|")
        guard parts.count == 3, let lat = Double(parts[1]), let lon = Double(parts[2]) else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        guard let nearest = places.min(by: {
            GeoMath.distanceMeters($0.coordinate, coordinate) < GeoMath.distanceMeters($1.coordinate, coordinate)
        }), GeoMath.distanceMeters(nearest.coordinate, coordinate) <= 200 else { return nil }
        return nearest
    }

    // MARK: - Stage 5 (chronological First detection)

    private func createFirsts(from pairs: [(Stay, Place?)]) throws -> Int {
        var created = 0
        var handledPlaceKeys: Set<String> = []

        for (stay, place) in pairs.sorted(by: { $0.0.startDate < $1.0.startDate }) {
            guard let place, place.role == .none, stay.qualifiesForFirst else { continue }
            guard !handledPlaceKeys.contains(place.key) else { continue }
            handledPlaceKeys.insert(place.key)

            guard stay.startDate == place.firstSeenAt else { continue }
            guard !place.firsts.contains(where: { $0.level == .place }) else { continue }

            modelContext.insert(First(
                level: .place, occurredAt: stay.startDate, title: place.displayName,
                latitude: place.latitude, longitude: place.longitude, confidence: stay.confidence, place: place
            ))
            created += 1
        }
        return created
    }

    // Cheap, robust coarse Firsts (neighborhood/city/region/country) from the hierarchy already
    // recorded on every Place. Unlike place-level Firsts these aren't gated on role or
    // qualifiesForFirst — even a single low-confidence photo reliably tells you what city you were
    // in, which is a far lower evidence bar than "this specific named place is a real first".
    private func createCoarseFirsts(from pairs: [(Stay, Place?)]) throws -> Int {
        let existing = try modelContext.fetch(FetchDescriptor<First>())
        var seenKeys = Set(existing.compactMap { first -> String? in
            guard first.level != .place, let key = first.coarseKey else { return nil }
            return "\(first.level.rawValue)|\(key)"
        })

        var created = 0
        for (stay, place) in pairs.sorted(by: { $0.0.startDate < $1.0.startDate }) {
            guard let place else { continue }
            let levels: [(FirstLevel, String?)] = [
                (.neighborhood, place.neighborhood), (.city, place.city),
                (.region, place.region), (.country, place.country),
            ]
            for (level, value) in levels {
                guard let value, !value.isEmpty else { continue }
                let seenKey = "\(level.rawValue)|\(value)"
                guard !seenKeys.contains(seenKey) else { continue }
                seenKeys.insert(seenKey)
                modelContext.insert(First(
                    level: level, occurredAt: stay.startDate, title: value, coarseKey: value,
                    latitude: place.latitude, longitude: place.longitude, confidence: stay.confidence
                ))
                created += 1
            }
        }
        return created
    }
}
