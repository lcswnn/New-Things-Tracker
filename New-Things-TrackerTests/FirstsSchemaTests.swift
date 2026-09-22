import Testing
import Foundation
import SwiftData
@testable import New_Things_Tracker

// @Relationship(inverse:) takes an untyped AnyKeyPath, so a wrong keypath fails at runtime, not
// compile time — these tests exist specifically to catch that class of mistake, along with wrong
// delete rules, before Phase 4 builds anything on top of the schema.
@Suite("FirstsSchema relationships")
struct FirstsSchemaTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: PresenceSignal.self, Stay.self, PlaceCandidateRecord.self,
                 Place.self, First.self, GeoCacheEntry.self, UserCorrection.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("every relationship wires in both directions and survives a save")
    func relationshipsWireBothWays() throws {
        let context = ModelContext(try makeContainer())

        let stay = Stay(startDate: .now, endDate: .now.addingTimeInterval(3600),
                         latitude: 41.88, longitude: -87.63, radiusMeters: 50)
        let place = Place(key: "test-key", displayName: "Test Place", normalizedName: "test place",
                           geohash7: "dp3wjb0", latitude: 41.88, longitude: -87.63,
                           firstSeenAt: .now, lastSeenAt: .now)
        let signal = PresenceSignal(sourceKind: .visit, timestamp: .now, endTimestamp: .now.addingTimeInterval(1800),
                                     latitude: 41.88, longitude: -87.63, horizontalAccuracy: 20)
        let candidate = PlaceCandidateRecord(rank: 0, score: 0.9, displayName: "Test Place",
                                              latitude: 41.88, longitude: -87.63)
        let first = First(level: .place, occurredAt: .now, title: "First time at Test Place",
                           latitude: 41.88, longitude: -87.63, confidence: 0.9)

        signal.stay = stay
        candidate.stay = stay
        stay.place = place
        first.place = place

        for model in [stay, place, signal, candidate, first] as [any PersistentModel] {
            context.insert(model)
        }
        try context.save()

        let fetchedPlace = try #require(try context.fetch(FetchDescriptor<Place>()).first)
        #expect(fetchedPlace.stays.count == 1)
        #expect(fetchedPlace.firsts.count == 1)

        let fetchedStay = try #require(fetchedPlace.stays.first)
        #expect(fetchedStay.signals.count == 1)
        #expect(fetchedStay.candidates.count == 1)
        #expect(fetchedStay.place?.key == "test-key")
    }

    @Test("deleting a Stay cascades its candidates but only nullifies its signals")
    func stayDeletionCascadesCandidatesNullifiesSignals() throws {
        let context = ModelContext(try makeContainer())

        let stay = Stay(startDate: .now, endDate: .now, latitude: 0, longitude: 0, radiusMeters: 10)
        let signal = PresenceSignal(sourceKind: .visit, timestamp: .now, endTimestamp: nil,
                                     latitude: 0, longitude: 0, horizontalAccuracy: 10)
        let candidate = PlaceCandidateRecord(rank: 0, score: 0.5, displayName: "X", latitude: 0, longitude: 0)
        signal.stay = stay
        candidate.stay = stay

        context.insert(stay)
        context.insert(signal)
        context.insert(candidate)
        try context.save()

        context.delete(stay)
        try context.save()

        // PresenceSignal (CLVisit data) is the one unrecoverable log in this schema — rebuilding
        // Stay each import run must never destroy it, only detach it (stay becomes nil).
        let remainingSignals = try context.fetch(FetchDescriptor<PresenceSignal>())
        #expect(remainingSignals.count == 1)
        #expect(remainingSignals.first?.stay == nil)
        #expect(try context.fetch(FetchDescriptor<PlaceCandidateRecord>()).isEmpty)
    }

    @Test("deleting a Place nullifies its Stays but cascades its Firsts")
    func placeDeletionNullifiesStaysAndCascadesFirsts() throws {
        let context = ModelContext(try makeContainer())

        let place = Place(key: "p1", displayName: "P", normalizedName: "p", geohash7: "abc",
                           latitude: 0, longitude: 0, firstSeenAt: .now, lastSeenAt: .now)
        let stay = Stay(startDate: .now, endDate: .now, latitude: 0, longitude: 0, radiusMeters: 10)
        let first = First(level: .place, occurredAt: .now, title: "First", latitude: 0, longitude: 0, confidence: 1)
        stay.place = place
        first.place = place

        context.insert(place)
        context.insert(stay)
        context.insert(first)
        try context.save()

        context.delete(place)
        try context.save()

        let remainingStays = try context.fetch(FetchDescriptor<Stay>())
        #expect(remainingStays.count == 1)
        #expect(remainingStays.first?.place == nil)
        #expect(try context.fetch(FetchDescriptor<First>()).isEmpty)
    }

    @Test("Place.key lookup works without a unique constraint")
    func placeKeyLookupByIndex() throws {
        let context = ModelContext(try makeContainer())
        context.insert(Place(key: "cafe-1", displayName: "Cafe", normalizedName: "cafe", geohash7: "dp3wjb0",
                              latitude: 0, longitude: 0, firstSeenAt: .now, lastSeenAt: .now))
        try context.save()

        let descriptor = FetchDescriptor<Place>(predicate: #Predicate { $0.key == "cafe-1" })
        #expect(try context.fetch(descriptor).count == 1)
    }
}
