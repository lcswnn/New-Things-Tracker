import Foundation
import CoreLocation

// Stage 2: greedy single-pass clustering of chronological signals into Stays (stay-point detection),
// with transit rejection. Pure and nonisolated so it's callable from the @ModelActor importer
// without a hop, and unit-testable without SwiftData or CoreLocation managers.
nonisolated enum StayBuilder {

    static func buildStays(from signals: [PresenceSignalDraft], tuning: PipelineTuning = .default) -> [StayDraft] {
        let sorted = signals.sorted { $0.timestamp < $1.timestamp }
        var stays: [StayDraft] = []
        var current: [PresenceSignalDraft] = []

        func flush() {
            guard !current.isEmpty else { return }
            stays.append(finalize(current, tuning: tuning))
            current = []
        }

        for signal in sorted {
            if let last = current.last {
                let distance = GeoMath.distanceMeters(last.coordinate, signal.coordinate)
                let gap = signal.timestamp.timeIntervalSince(last.timestamp)
                if distance > tuning.joinDistanceMeters || gap > tuning.joinTimeGap {
                    flush()
                }
            }
            current.append(signal)
        }
        flush()

        return stays
    }

    // A stay is discarded as transit only when it has no CLVisit anchor — a visit means the system
    // itself judged this a stop, which overrides a noisy speed estimate from sparse photo GPS.
    private static func finalize(_ signals: [PresenceSignalDraft], tuning: PipelineTuning) -> StayDraft {
        let hasVisit = signals.contains { $0.kind == .visit }
        let speeds = impliedSpeedsKmh(signals)
        let medianSpeed = median(speeds) ?? 0
        let isTransit = signals.count >= 2 && !hasVisit && medianSpeed > tuning.transitSpeedKmh

        let centroid = accuracyWeightedCentroid(signals)
        let radius = signals.map { GeoMath.distanceMeters($0.coordinate, centroid) }.max() ?? 0
        let startDate = signals.map(\.timestamp).min()!
        let endDate = signals.map { $0.endTimestamp ?? $0.timestamp }.max()!

        return StayDraft(
            startDate: startDate,
            endDate: endDate,
            latitude: centroid.latitude,
            longitude: centroid.longitude,
            radiusMeters: radius,
            photoLocalIdentifiers: signals.compactMap(\.assetLocalIdentifier),
            visitSignals: signals.filter { $0.kind == .visit },
            medianImpliedSpeedKmh: medianSpeed,
            isDiscarded: isTransit,
            discardReason: isTransit ? "transit" : nil
        )
    }

    // Weighted by inverse accuracy so a precise signal pulls the centroid toward it more than a
    // vague one; signals with unknown/invalid accuracy (<= 0) fall back to an assumed 10m.
    private static func accuracyWeightedCentroid(_ signals: [PresenceSignalDraft]) -> CLLocationCoordinate2D {
        var weightedLat = 0.0, weightedLon = 0.0, totalWeight = 0.0
        for signal in signals {
            let accuracy = signal.horizontalAccuracy > 0 ? signal.horizontalAccuracy : 10
            let weight = 1.0 / accuracy
            weightedLat += signal.latitude * weight
            weightedLon += signal.longitude * weight
            totalWeight += weight
        }
        return CLLocationCoordinate2D(latitude: weightedLat / totalWeight, longitude: weightedLon / totalWeight)
    }

    private static func impliedSpeedsKmh(_ signals: [PresenceSignalDraft]) -> [Double] {
        guard signals.count >= 2 else { return [] }
        var speeds: [Double] = []
        for i in 1..<signals.count {
            let dt = signals[i].timestamp.timeIntervalSince(signals[i - 1].timestamp)
            guard dt > 0 else { continue }
            let distanceKm = GeoMath.distanceMeters(signals[i - 1].coordinate, signals[i].coordinate) / 1000
            speeds.append(distanceKm / (dt / 3600))
        }
        return speeds
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
