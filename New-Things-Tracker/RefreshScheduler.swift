import Foundation
import BackgroundTasks

// Stage 6 background behavior: periodically re-runs FirstsStore.runBackfill() via
// BGProcessingTaskRequest (not BGAppRefreshTaskRequest — Stage 3's MapKit/geocoder calls need
// network access and can take a while, which is exactly what BGProcessingTask is for) so new
// firsts keep appearing without the user opening the app.
//
// Device-only: BGTaskScheduler.submit/submitTaskRequest always returns/throws .unavailable in the
// simulator, so none of this is verifiable there.
enum RefreshScheduler {
    static let identifier = "com.spot-location.New-Things-Tracker.refresh"

    // Registering the same identifier twice terminates the app, so this must run exactly once,
    // synchronously, before application(_:didFinishLaunchingWithOptions:) returns.
    private static var isRegistered = false

    @MainActor
    static func registerHandlers(store: FirstsStore) {
        guard !isRegistered else { return }
        isRegistered = true

        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                handle(processingTask, store: store)
            }
        }

        // Keep one request pending at all times, not just after the app backgrounds — otherwise a
        // fresh install with no background/foreground transition would never get a first refresh.
        scheduleNext()
    }

    @MainActor
    private static func handle(_ task: BGProcessingTask, store: FirstsStore) {
        scheduleNext() // BGProcessingTaskRequest is one-shot; always resubmit before doing the work

        let work = Task {
            await store.runBackfill()
            task.setTaskCompleted(success: true)
        }
        // Best-effort cancellation: runFullBackfill doesn't currently poll Task.isCancelled
        // mid-pipeline, so this stops new work from starting but won't interrupt an in-flight
        // MapKit/geocoder call. Good enough to avoid corrupting state; not a hard deadline.
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    static func scheduleNext(earliestBeginDate: Date = Date(timeIntervalSinceNow: 4 * 3600)) {
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = earliestBeginDate

        if #available(iOS 27.0, *) {
            Task { try? await BGTaskScheduler.shared.submitTaskRequest(request) }
        } else {
            try? BGTaskScheduler.shared.submit(request) // deprecated ios(13.0, 27.0); no earlier path exists
        }
    }
}
