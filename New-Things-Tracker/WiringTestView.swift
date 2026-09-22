import SwiftUI
import CoreLocation

struct WiringTestView: View {

    @StateObject private var loc = LocationHistoryManager()
    @ObservedObject private var store: FirstsStore

    @State private var mergedLog: [(id: Int, line: String)] = []
    @State private var logCounter = 0
    @State private var selectedTab = 0   // 0 = Log, 1 = Places, 2 = Review

    init(environment: AppEnvironment) {
        _store = ObservedObject(wrappedValue: environment.store)
    }

    var body: some View {
        VStack(spacing: 0) {

            // — Stats chips —
            HStack(spacing: 0) {
                chip(value: "\(loc.visits.count)", label: "visits", icon: "mappin.circle.fill", color: .blue)
                chip(value: "\(store.places.count)", label: "places", icon: "star.fill", color: .yellow)
                chip(value: "\(store.pendingReview.count)", label: "review", icon: "questionmark.circle.fill", color: .orange)
            }
            .padding(.vertical, 12)

            // — Action buttons —
            HStack(spacing: 10) {
                actionButton("Fetch Location History", icon: "location.fill", color: .blue) {
                    loc.requestPermissionAndStart()
                }
                actionButton(store.isImporting ? "Running…" : "Run Backfill", icon: "arrow.clockwise", color: .green) {
                    Task { await store.runBackfill() }
                }
            }
            .padding(.horizontal, 14)
            .disabled(store.isImporting)

            // — Tab picker —
            Picker("View", selection: $selectedTab) {
                Text("Log").tag(0)
                Text("Places (\(store.places.count))").tag(1)
                Text("Review (\(store.pendingReview.count))").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.top, 10)

            Divider().padding(.top, 8)

            switch selectedTab {
            case 1:  placesList
            case 2:  reviewList
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
        .onChange(of: store.log) { old, new in
            for line in new.dropFirst(old.count) {
                mergedLog.append((id: logCounter, line: "[STORE] \(line)"))
                logCounter += 1
            }
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

    // MARK: - Places

    private var placesList: some View {
        Group {
            if store.places.isEmpty {
                emptyState(icon: "star.slash", text: "No places yet — run a backfill first.")
            } else {
                List(store.places) { summary in
                    placeRow(summary)
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func placeRow(_ summary: PlaceSummary) -> some View {
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
                    Text("\(summary.visitCount)×")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.placeName).font(.subheadline.weight(.semibold))
                Text("First visit: \(dateFmt.string(from: summary.firstVisitDate))")
                    .font(.caption).foregroundColor(.secondary)
                Text("\(summary.visitCount) visit\(summary.visitCount == 1 ? "" : "s") · \(summary.totalPhotoCount) photo\(summary.totalPhotoCount == 1 ? "" : "s")")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Review

    private var reviewList: some View {
        Group {
            if store.pendingReview.isEmpty {
                emptyState(icon: "checkmark.circle", text: "Nothing needs review.")
            } else {
                List(store.pendingReview) { candidate in
                    reviewRow(candidate)
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func reviewRow(_ candidate: ReviewCandidate) -> some View {
        let dateFmt: DateFormatter = {
            let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
        }()
        VStack(alignment: .leading, spacing: 3) {
            Text(candidate.placeName).font(.subheadline.weight(.semibold))
            Text(dateFmt.string(from: candidate.firstVisitDate))
                .font(.caption).foregroundColor(.secondary)
            Text("\(candidate.totalPhotoCount) photo\(candidate.totalPhotoCount == 1 ? "" : "s")")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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
