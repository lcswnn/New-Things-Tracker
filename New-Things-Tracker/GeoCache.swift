import Foundation
import SwiftData

// Memoized MapKit lookups keyed by geohash7 (~150m cells), replacing the previous unbounded
// "geocache_%.3f_%.3f" UserDefaults keys, which were never purged. Free functions taking a
// ModelContext rather than an owning type, since the real ModelContext lives on the @ModelActor
// importer (Phase 4) — this stays a thin, directly testable layer over it.
nonisolated enum GeoCache {
    static let ttl: TimeInterval = 30 * 24 * 3600

    static func lookup(geohash7: String, in context: ModelContext, now: Date = .now) throws -> [POICandidateDraft]? {
        guard let entry = try existingEntry(for: geohash7, in: context) else { return nil }
        guard now.timeIntervalSince(entry.fetchedAt) < ttl else { return nil }
        return try JSONDecoder().decode([POICandidateDraft].self, from: entry.payload)
    }

    static func store(geohash7: String, candidates: [POICandidateDraft], in context: ModelContext, now: Date = .now) throws {
        let payload = try JSONEncoder().encode(candidates)
        if let existing = try existingEntry(for: geohash7, in: context) {
            existing.payload = payload
            existing.fetchedAt = now
        } else {
            context.insert(GeoCacheEntry(geohash7: geohash7, fetchedAt: now, payload: payload))
        }
    }

    // Run at the end of each import pass so the cache can't grow without bound. This is a batch
    // delete against the persisted store, not the context's pending changes — call it after a
    // save(), or entries written earlier in the same run won't be visible to it yet.
    static func evictExpired(in context: ModelContext, now: Date = .now) throws {
        let cutoff = now.addingTimeInterval(-ttl)
        try context.delete(model: GeoCacheEntry.self, where: #Predicate { $0.fetchedAt < cutoff })
    }

    private static func existingEntry(for geohash7: String, in context: ModelContext) throws -> GeoCacheEntry? {
        var descriptor = FetchDescriptor<GeoCacheEntry>(predicate: #Predicate { $0.geohash7 == geohash7 })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
