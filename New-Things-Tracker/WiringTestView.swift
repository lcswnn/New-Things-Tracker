import SwiftUI
import CoreLocation

struct WiringTestView: View {

    @StateObject private var loc   = LocationHistoryManager()
    @StateObject private var photo = PhotoMetadataManager()

    @State private var mergedLog: [(id: Int, line: String)] = []
    @State private var logCounter = 0
    @State private var selectedTab = 0   // 0 = Log, 1 = Clusters, 2 = Firsts

    var body: some View {
        VStack(spacing: 0) {

            // — Stats chips —
            HStack(spacing: 0) {
                chip(value: "\(loc.visits.count)",
                     label: "visits",
                     icon: "mappin.circle.fill",
                     color: .blue)
                chip(value: "\(photo.items.count)",
                     label: "photos",
                     icon: "photo.fill",
                     color: .green)
                chip(value: "\(photo.items.filter { $0.coordinate != nil }.count)",
                     label: "w/ GPS",
                     icon: "location.fill",
                     color: .orange)
                chip(value: "\(photo.placeCandidates.count)",
                     label: "firsts",
                     icon: "star.fill",
                     color: .yellow)
            }
            .padding(.vertical, 12)

            // — Action buttons —
            HStack(spacing: 10) {
                actionButton("Fetch Location History", icon: "location.fill", color: .blue) {
                    loc.requestPermissionAndStart()
                }
                actionButton("Fetch Photo Metadata", icon: "photo.fill", color: .green) {
                    photo.requestPermissionAndFetch()
                }
            }
            .padding(.horizontal, 14)

            Button(action: clearGeocodeCache) {
                Label("Clear Geocode Cache", systemImage: "trash")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.red)
                    .padding(.vertical, 6)
            }

            // — Tab picker —
            Picker("View", selection: $selectedTab) {
                Text("Log").tag(0)
                Text("Clusters (\(photo.clusters.count))").tag(1)
                Text("Firsts (\(photo.placeCandidates.count))").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.top, 10)

            Divider().padding(.top, 8)

            switch selectedTab {
            case 1:  clusterList
            case 2:  firstsList
            default: logView
            }
        }
        .navigationTitle("Data Wiring Test")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: loc.log) { old, new in
            for line in new.dropFirst(old.count) {
                mergedLog.append((id: logCounter, line: "[LOC]   \(line)"))
                logCounter += 1
            }
        }
        .onChange(of: photo.log) { old, new in
            for line in new.dropFirst(old.count) {
                mergedLog.append((id: logCounter, line: "[PHOTO] \(line)"))
                logCounter += 1
            }
        }
        .onChange(of: photo.placeCandidates.count) { _, count in
            if count > 0 { selectedTab = 2 }
        }
    }

    // MARK: - Log

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(mergedLog, id: \.id) { entry in
                        Text(entry.line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(entry.line.hasPrefix("[LOC]") ? .blue : .green)
                            .id(entry.id)
                    }
                }
                .padding(10)
            }
            .onChange(of: mergedLog.count) { _, _ in
                if let last = mergedLog.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    // MARK: - Clusters (raw per-day)

    private var clusterList: some View {
        Group {
            if photo.clusters.isEmpty {
                emptyState(icon: "square.stack.3d.up.slash", text: "No clusters yet — fetch photo metadata first.")
            } else {
                List(photo.clusters) { cluster in
                    clusterRow(cluster)
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func clusterRow(_ cluster: PhotoCluster) -> some View {
        let fmt: DateFormatter = {
            let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
        }()
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 44, height: 44)
                VStack(spacing: 0) {
                    Text("\(cluster.count)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                    Text("📷").font(.system(size: 10))
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(String(format: "%.4f,  %.4f",
                            cluster.centroid.latitude,
                            cluster.centroid.longitude))
                    .font(.system(size: 12, design: .monospaced))
                Text(fmt.string(from: cluster.day))
                    .font(.caption).foregroundColor(.secondary)
                Text("\(cluster.count) photo\(cluster.count == 1 ? "" : "s")")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Firsts (cross-day unique places)

    private var firstsList: some View {
        Group {
            if photo.placeCandidates.isEmpty {
                emptyState(icon: "star.slash", text: "No unique places yet — fetch photo metadata first.")
            } else {
                if photo.isGeocodingPlaces {
                    HStack(spacing: 6) {
                        ProgressView()
                        Text("Geocoding place names…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                List(photo.placeCandidates) { candidate in
                    candidateRow(candidate)
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func candidateRow(_ candidate: PlaceCandidate) -> some View {
        let dateFmt: DateFormatter = {
            let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
        }()
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.15))
                    .frame(width: 44, height: 44)
                VStack(spacing: 1) {
                    Text("⭐️").font(.system(size: 18))
                    Text("\(candidate.visitCount)×")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                if let name = candidate.placeName {
                    Text(name).font(.subheadline.weight(.semibold))
                } else if photo.isGeocodingPlaces {
                    HStack(spacing: 5) {
                        ProgressView().scaleEffect(0.7)
                        Text("Resolving…").font(.subheadline).foregroundColor(.secondary)
                    }
                } else {
                    Text(String(format: "%.4f, %.4f",
                                candidate.centroid.latitude,
                                candidate.centroid.longitude))
                        .font(.system(size: 12, design: .monospaced))
                }
                Text("First visit: \(dateFmt.string(from: candidate.firstVisitDate))")
                    .font(.caption).foregroundColor(.secondary)
                Text("\(candidate.visitCount) day\(candidate.visitCount == 1 ? "" : "s") · \(candidate.totalPhotoCount) photo\(candidate.totalPhotoCount == 1 ? "" : "s")")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Cache management

    private func clearGeocodeCache() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("geocache_") {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Shared sub-views

    @ViewBuilder
    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func chip(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.caption2)
                Text(value).font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(color)
            Text(label).font(.system(size: 9)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(color.opacity(0.12))
                .foregroundColor(color)
                .cornerRadius(10)
        }
    }
}
