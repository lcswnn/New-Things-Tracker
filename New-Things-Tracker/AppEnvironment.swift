import Foundation
import SwiftData

// Owns the SwiftData stack. AppDelegate builds this in didFinishLaunchingWithOptions (required so
// BGTask registration — see Phase 6 — can complete before that method returns) and SceneDelegate
// property-injects it into the storyboard-instantiated ViewController. ViewController must only
// read it from viewDidAppear, never viewDidLoad: UIKit can call viewDidLoad before
// scene(_:willConnectTo:) runs, so the environment may not be set yet at that point.
struct AppEnvironment {
    let container: ModelContainer
    let store: FirstsStore
}

extension AppEnvironment {
    @MainActor
    static func bootstrap() -> AppEnvironment {
        let container = openContainer()
        LegacyMigration.migrateIfNeeded(context: container.mainContext)
        return AppEnvironment(container: container, store: FirstsStore(container: container))
    }

    private static func openContainer() -> ModelContainer {
        if let container = try? makeContainer(at: storeURL) {
            return container
        }

        // Every model except UserCorrection is derived from the photo library and MapKit, so a
        // corrupt or schema-incompatible store is safe to wipe and rebuild rather than crash on
        // launch. (UserCorrection loss here is a last resort; LegacyMigration mirroring corrections
        // ahead of a store recreation is what actually protects it in the ordinary case.)
        removeStoreFiles(at: storeURL)
        guard let container = try? makeContainer(at: storeURL) else {
            fatalError("Unable to create the Firsts model container even after wiping \(storeURL.path)")
        }
        return container
    }

    private static func makeContainer(at url: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let configuration = ModelConfiguration(url: url)
        return try ModelContainer(
            for: PresenceSignal.self, Stay.self, PlaceCandidateRecord.self,
                 Place.self, First.self, GeoCacheEntry.self, UserCorrection.self,
            configurations: configuration
        )
    }

    private static var storeURL: URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return supportDir.appending(path: "FirstsStore.sqlite")
    }

    private static func removeStoreFiles(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            try? fm.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }
}
