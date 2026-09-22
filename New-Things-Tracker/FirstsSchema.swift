import Foundation
import SwiftData
import CoreLocation

// SwiftData models for the Firsts detection pipeline (see Stages 1-6 in the algorithm spec).
// All seven models live in this one file so the schema list passed to ModelContainer can never
// drift from the set of @Model declarations that actually exist.
//
// Every enum here is nonisolated and raw-value (never an associated value) so it stays usable
// inside #Predicate — an associated-value enum would need @Attribute(.codable), which throws
// SwiftDataError.unsupportedPredicate at runtime the moment it's used in a predicate or sort.
//
// Every @Model class is nonisolated: the app target sets SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor,
// which would otherwise pin these declarations to the main actor. Models must be reachable from
// both the @MainActor FirstsStore (UI reads) and the @ModelActor FirstsImporter (background writes).

nonisolated enum SignalSourceKind: String, Codable, CaseIterable, Sendable {
    case visit
}

nonisolated enum ResolutionStatus: String, Codable, CaseIterable, Sendable {
    case unresolved, resolved, needsConfirmation, confirmed, discarded
}

nonisolated enum FirstLevel: String, Codable, CaseIterable, Sendable {
    case place, neighborhood, city, region, country
}

nonisolated enum PlaceRole: String, Codable, CaseIterable, Sendable {
    case none, home, work, privateResidence
}

// .merge(into:) from the spec is flattened to `.merge` + UserCorrection.mergeTargetKey — an
// associated value here would make `kind` unusable in a #Predicate.
nonisolated enum CorrectionKind: String, Codable, CaseIterable, Sendable {
    case confirm, rename, merge, notAPlace, markHome, markWork, markPrivate, categoryFix
}

// Stage 3 scores against these ~12 groups rather than the 83 raw MKPointOfInterestCategory
// values, so Stage 6's learned weight adjustments have far fewer dials to overfit.
nonisolated enum PlaceCategoryGroup: String, Codable, CaseIterable, Sendable {
    case unknown, outdoors, culture, foodAndDrink, lodging, retail, transit, services, fitness, education, nightlife
    // Gas stations, parking, ATMs, EV chargers, restrooms — the spec keeps these far below
    // `services` (0.05 vs 0.2) so a "first" is never created at a pit stop next to a real place.
    case utility
}

// MARK: - PresenceSignal

// Only CLVisit-derived signals are persisted. Photo-derived signals are always re-derivable from
// PHAsset and would be 10k-50k rows of redundant data; visit evidence is ephemeral and would be
// lost forever if dropped. Photo evidence instead lives on Stay.photoLocalIdentifiers.
@Model
nonisolated final class PresenceSignal {
    var sourceKind: SignalSourceKind
    var timestamp: Date
    var endTimestamp: Date?
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double

    var stay: Stay?

    init(
        sourceKind: SignalSourceKind,
        timestamp: Date,
        endTimestamp: Date?,
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double
    ) {
        self.sourceKind = sourceKind
        self.timestamp = timestamp
        self.endTimestamp = endTimestamp
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Stay

@Model
nonisolated final class Stay {
    var startDate: Date
    var endDate: Date
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var photoLocalIdentifiers: [String]
    var resolution: ResolutionStatus
    var medianImpliedSpeedKmh: Double
    var confidence: Double
    // Set by Stage 3: true when there's enough evidence to auto-create a First (has photos, or a
    // visit with a valid >=10min dwell, or — when the visit's dates are unknown — a resolution
    // confidence above minConfidenceToAutoAccept). Stored here so Stage 5 doesn't need to
    // re-derive it from `signals`, which may be only loosely associated with a rebuilt Stay.
    var qualifiesForFirst: Bool
    // Set once the user explicitly acts on this Stay (confirm, or a Phase 5 correction). Every
    // import run wipes and rebuilds Stay from scratch, so without this flag a user's decision would
    // be silently re-resolved (and potentially overwritten) on the very next backfill. The importer
    // matches rebuilt stays back to their prior selves by (startDate, endDate) — stable as long as
    // the underlying evidence for that stay hasn't changed — and skips re-resolution for matches.
    var userReviewed: Bool

    // .nullify, not .cascade: PresenceSignal (CLVisit data) is the one unrecoverable log in this
    // schema, while Stay is fully re-derivable from it plus fresh PHAsset fetches. Every import run
    // wipes and rebuilds Stay/PlaceCandidateRecord — a cascade here would destroy visit history
    // every time that happens.
    @Relationship(deleteRule: .nullify, inverse: \PresenceSignal.stay)
    var signals: [PresenceSignal] = []

    var place: Place?

    @Relationship(deleteRule: .cascade, inverse: \PlaceCandidateRecord.stay)
    var candidates: [PlaceCandidateRecord] = []

    init(
        startDate: Date,
        endDate: Date,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        photoLocalIdentifiers: [String] = [],
        resolution: ResolutionStatus = .unresolved,
        medianImpliedSpeedKmh: Double = 0,
        confidence: Double = 0,
        qualifiesForFirst: Bool = false,
        userReviewed: Bool = false
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.photoLocalIdentifiers = photoLocalIdentifiers
        self.userReviewed = userReviewed
        self.resolution = resolution
        self.medianImpliedSpeedKmh = medianImpliedSpeedKmh
        self.confidence = confidence
        self.qualifiesForFirst = qualifiesForFirst
    }

    var centroid: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - PlaceCandidateRecord

// The top-3 scored POI candidates for a Stay awaiting confirmation. A dedicated model instead of
// parallel arrays on Stay (candidateNames/candidateScores/...), which is exactly the bug already
// fixed once in ViewController.pastSections.
@Model
nonisolated final class PlaceCandidateRecord {
    var rank: Int
    var score: Double
    var displayName: String
    var mapKitIdentifier: String?
    var poiCategoryRaw: String?
    var latitude: Double
    var longitude: Double

    var stay: Stay?

    init(
        rank: Int,
        score: Double,
        displayName: String,
        mapKitIdentifier: String? = nil,
        poiCategoryRaw: String? = nil,
        latitude: Double,
        longitude: Double
    ) {
        self.rank = rank
        self.score = score
        self.displayName = displayName
        self.mapKitIdentifier = mapKitIdentifier
        self.poiCategoryRaw = poiCategoryRaw
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - Place

@Model
nonisolated final class Place {
    #Index<Place>([\.key], [\.normalizedName])

    // Canonical key = mapKitIdentifier ?? "normalizedName|geohash7", assigned AFTER the 40m
    // spatial merge (see PlaceScorer) — geohash7 cells are ~153m, wider than the merge radius,
    // so keying before merging can mint duplicate Places across a cell boundary.
    //
    // Deliberately NOT @Attribute(.unique): uniqueness is upsert semantics, and a re-resolve
    // under a changed mapKitIdentifier (Apple warns these "may change over time") would silently
    // overwrite firstSeenAt — the one fact this whole app exists to preserve. Uniqueness is
    // enforced in code (fetch-by-key-then-insert) since the merge rule is spatial anyway.
    var key: String
    var displayName: String
    var normalizedName: String
    var geohash7: String
    var mapKitIdentifier: String?
    var alternateIdentifiers: [String]
    var poiCategoryRaw: String?
    var categoryGroup: PlaceCategoryGroup
    var latitude: Double
    var longitude: Double
    // Coarse hierarchy from reverse geocoding, recorded on every Place regardless of resolution
    // outcome — this is what backs the .neighborhood/.city/.region/.country coarse Firsts.
    var neighborhood: String?
    var city: String?
    var region: String?
    var country: String?
    var role: PlaceRole
    // Once true, Stage 3 never overwrites displayName from a fresh MapKit/geocoder result again.
    var userRenamed: Bool
    var confidence: Double
    var firstSeenAt: Date
    var lastSeenAt: Date
    var visitCount: Int

    @Relationship(deleteRule: .nullify, inverse: \Stay.place)
    var stays: [Stay] = []

    @Relationship(deleteRule: .cascade, inverse: \First.place)
    var firsts: [First] = []

    init(
        key: String,
        displayName: String,
        normalizedName: String,
        geohash7: String,
        mapKitIdentifier: String? = nil,
        alternateIdentifiers: [String] = [],
        poiCategoryRaw: String? = nil,
        categoryGroup: PlaceCategoryGroup = .unknown,
        latitude: Double,
        longitude: Double,
        neighborhood: String? = nil,
        city: String? = nil,
        region: String? = nil,
        country: String? = nil,
        role: PlaceRole = .none,
        userRenamed: Bool = false,
        confidence: Double = 0,
        firstSeenAt: Date,
        lastSeenAt: Date,
        visitCount: Int = 0
    ) {
        self.key = key
        self.displayName = displayName
        self.normalizedName = normalizedName
        self.geohash7 = geohash7
        self.mapKitIdentifier = mapKitIdentifier
        self.alternateIdentifiers = alternateIdentifiers
        self.poiCategoryRaw = poiCategoryRaw
        self.categoryGroup = categoryGroup
        self.latitude = latitude
        self.longitude = longitude
        self.neighborhood = neighborhood
        self.city = city
        self.region = region
        self.country = country
        self.role = role
        self.userRenamed = userRenamed
        self.confidence = confidence
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.visitCount = visitCount
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - First

@Model
nonisolated final class First {
    var level: FirstLevel
    var occurredAt: Date
    var title: String
    var subtitle: String?
    // Identity for coarse (non-.place) firsts, e.g. a city or country name; nil for .place level,
    // which is identified through `place` instead.
    var coarseKey: String?
    var latitude: Double
    var longitude: Double
    var confidence: Double

    var place: Place?

    init(
        level: FirstLevel,
        occurredAt: Date,
        title: String,
        subtitle: String? = nil,
        coarseKey: String? = nil,
        latitude: Double,
        longitude: Double,
        confidence: Double,
        place: Place? = nil
    ) {
        self.level = level
        self.occurredAt = occurredAt
        self.title = title
        self.subtitle = subtitle
        self.coarseKey = coarseKey
        self.latitude = latitude
        self.longitude = longitude
        self.confidence = confidence
        self.place = place
    }
}

// MARK: - GeoCacheEntry

// Memoized MapKit/geocoder lookups keyed by geohash7, replacing the unbounded
// "geocache_%.3f_%.3f" UserDefaults keys from the previous implementation.
@Model
nonisolated final class GeoCacheEntry {
    #Index<GeoCacheEntry>([\.geohash7])

    var geohash7: String
    var fetchedAt: Date
    var payload: Data

    init(geohash7: String, fetchedAt: Date, payload: Data) {
        self.geohash7 = geohash7
        self.fetchedAt = fetchedAt
        self.payload = payload
    }
}

// MARK: - UserCorrection

// The only user-authored model — everything else is derived data that a backfill can rebuild.
// Keyed on the canonical Place.key STRING, never a Place relationship, so corrections survive a
// full rebuild of the derived data (the migration path wipes and re-backfills everything else).
@Model
nonisolated final class UserCorrection {
    var kind: CorrectionKind
    var createdAt: Date
    var placeKey: String
    var mergeTargetKey: String?
    var newName: String?
    var categoryGroup: PlaceCategoryGroup?

    init(
        kind: CorrectionKind,
        createdAt: Date = .now,
        placeKey: String,
        mergeTargetKey: String? = nil,
        newName: String? = nil,
        categoryGroup: PlaceCategoryGroup? = nil
    ) {
        self.kind = kind
        self.createdAt = createdAt
        self.placeKey = placeKey
        self.mergeTargetKey = mergeTargetKey
        self.newName = newName
        self.categoryGroup = categoryGroup
    }
}
