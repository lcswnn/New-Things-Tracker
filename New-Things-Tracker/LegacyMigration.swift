import Foundation
import SwiftData

// One-time migration from the pre-SwiftData UserDefaults state, run once before the first
// backfill. The lossy "geocache_%.3f_%.3f" name cache is deliberately NOT migrated — it's the
// output of the exact "first POI within 100m wins" logic this rewrite replaces.
nonisolated enum LegacyMigration {
    private static let migratedKey = "firstsSwiftDataMigrationCompleted"

    static func migrateIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }

        migrateHomeAndWork(context: context)
        purgeLegacyGeocache()

        UserDefaults.standard.set(true, forKey: migratedKey)
        try? context.save()
    }

    // reviewedPlaceKeys is intentionally left behind: it's keyed on a lossy 3-decimal centroid grid
    // with no reliable path to a canonical Place.key, so there's nothing safe to attach a
    // UserCorrection to. Those places go through Review once more — a one-time inconvenience, not
    // silent data loss (no user-authored fact is discarded).

    // Recorded against a coordinate-derived key, since no resolved Place exists yet at migration
    // time (this runs before the first backfill). FirstsImporter reconciles these against real
    // Places by proximity right after Stage 4 classification and rewrites the key once matched.
    private static func migrateHomeAndWork(context: ModelContext) {
        guard let data = UserDefaults.standard.data(forKey: "savedLocations"),
              let saved = try? JSONDecoder().decode([LegacySavedLocation].self, from: data) else { return }

        for location in saved {
            guard location.isSet, let lat = location.latitude, let lon = location.longitude else { continue }
            let kind: CorrectionKind
            switch location.id {
            case "home": kind = .markHome
            case "work": kind = .markWork
            default: continue
            }
            let key = "legacy|\(String(format: "%.5f", lat))|\(String(format: "%.5f", lon))"
            context.insert(UserCorrection(kind: kind, placeKey: key))
        }
    }

    private static func purgeLegacyGeocache() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("geocache_") {
            defaults.removeObject(forKey: key)
        }
    }
}

private struct LegacySavedLocation: Codable {
    var id: String
    var label: String
    var addressName: String?
    var latitude: Double?
    var longitude: Double?
    var isBuiltIn: Bool
    var isSet: Bool { latitude != nil }
}
