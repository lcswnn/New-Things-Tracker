import Foundation

// Canonical identity for Stage 3/5: key = mapKitIdentifier ?? "normalizedName|geohash7". Key
// assignment must happen AFTER the spatial merge step in the importer, not before — geohash7
// cells (~153m) are wider than the 40m merge radius, so keying first can mint duplicate Places
// across a cell boundary.
nonisolated enum PlaceIdentity {

    static func canonicalKey(mapKitIdentifier: String?, normalizedName: String, geohash7: String) -> String {
        mapKitIdentifier ?? "\(normalizedName)|\(geohash7)"
    }

    // Lowercased, diacritics stripped, punctuation removed, common trailing suffixes trimmed.
    static func normalize(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let stripped = String(String.UnicodeScalarView(folded.unicodeScalars.filter { allowed.contains($0) }))
        let collapsed = stripped
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")

        for suffix in trailingSuffixes {
            if collapsed.hasSuffix(" \(suffix)") {
                return String(collapsed.dropLast(suffix.count + 1))
            }
        }
        return collapsed
    }

    private static let trailingSuffixes = ["inc", "llc", "restaurant"]
}
