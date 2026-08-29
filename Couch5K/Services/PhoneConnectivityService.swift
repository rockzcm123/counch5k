import Foundation
import WatchConnectivity

/// Lets the Watch app pull this app's actual local workout history over
/// WatchConnectivity (see `WatchConnectivityService` on the Watch side),
/// and lets the Watch proactively ask this app to check HealthKit for new
/// Watch-completed workouts right now instead of waiting for the next
/// foreground/launch trigger — see `ProgramOverviewView.syncWatchWorkouts`.
@MainActor
final class PhoneConnectivityService: NSObject, ObservableObject {
    /// Set by the owning view; invoked when the Watch sends a "requestSync"
    /// message. Expected to run the existing HealthKit reconciliation and
    /// return only once it's actually finished, so the reply this sends
    /// back reflects the result rather than a stale snapshot.
    var onSyncRequested: (() async -> Void)?

    private var currentRecords: [WorkoutRecord] = []

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Called by the owning view whenever its local history changes, so a
    /// request from the Watch always has an up-to-date snapshot to answer
    /// from without this service needing its own SwiftData access.
    func update(records: [WorkoutRecord]) {
        currentRecords = records
        publishContext()
    }

    /// Best-effort background delivery to the Watch via WCSession's
    /// `applicationContext`. Unlike `sendMessage` (used by the explicit
    /// Pull/Push buttons), this doesn't require either app to be reachable
    /// right now — the system delivers it whenever it next can, including
    /// to a Watch app that's launching cold with this iPhone app not
    /// running. That's what the Watch reads immediately on launch (see
    /// `WatchConnectivityService.loadInitialHistory`), so it always has
    /// *something* to show without an error alert, instead of only ever
    /// working while this app happens to already be open.
    ///
    /// Safe to call before activation finishes — it silently no-ops until
    /// then, and gets retried by `activationDidCompleteWith` below once the
    /// session is actually ready.
    private func publishContext() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext(["history": encodedHistory()])
    }

    /// Does the actual reply-building work on the main actor (where
    /// `onSyncRequested` and `currentRecords` live), then hands back a
    /// plain `Data` — which is `Sendable` — so the caller in
    /// `didReceiveMessage:replyHandler:` never needs to run `replyHandler`
    /// itself from inside a main-actor-isolated closure.
    @MainActor
    private func buildReply(requestsSync: Bool) async -> Data {
        if requestsSync {
            await onSyncRequested?()
        }
        return encodedHistory()
    }

    private func encodedHistory() -> Data {
        let payload = currentRecords.map {
            WorkoutHistoryPayload(
                id: $0.id.uuidString,
                weekNumber: $0.weekNumber,
                sessionDay: $0.sessionDay,
                sessionSummary: $0.sessionSummary,
                plannedDuration: $0.plannedDuration,
                startedAt: $0.startedAt,
                completedAt: $0.completedAt,
                distanceMeters: $0.distanceMeters,
                workoutIdentifier: $0.workoutIdentifier,
                displayTitle: $0.displayTitle
            )
        }
        return (try? JSONEncoder().encode(payload)) ?? Data()
    }
}

extension PhoneConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // `publishContext()` no-ops until activation completes, so make
        // sure the Watch gets a fresh context as soon as it does — without
        // this, a context set via `update(records:)` before activation
        // finished (a likely ordering, since `update` runs before
        // `activate()` in ProgramOverviewView's launch `.task`) would
        // otherwise never get retried.
        Task { @MainActor [weak self] in
            self?.publishContext()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Required so this app keeps working if the user switches to a
        // different paired Watch.
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let requestsSync = (message["type"] as? String) == "requestSync"
        // `replyHandler` is an Apple-defined `([String: Any]) -> Void`
        // closure, not `Sendable`, so Swift 6 flags capturing it directly
        // into a new unstructured `Task` as a possible data race — even
        // though in practice it's called exactly once. `ReplyBox` wraps it
        // as `@unchecked Sendable` to make that intent explicit; the
        // "unchecked" is safe here specifically because nothing else holds
        // a reference to `replyHandler` outside this box.
        let box = ReplyBox(replyHandler)
        Task { [weak self] in
            guard let self else {
                box.reply([:])
                return
            }
            let data = await self.buildReply(requestsSync: requestsSync)
            box.reply(["history": data])
        }
    }
}

/// See the comment at its only call site, in
/// `didReceiveMessage:replyHandler:` above.
private final class ReplyBox: @unchecked Sendable {
    private let handler: ([String: Any]) -> Void

    init(_ handler: @escaping ([String: Any]) -> Void) {
        self.handler = handler
    }

    func reply(_ payload: [String: Any]) {
        handler(payload)
    }
}
