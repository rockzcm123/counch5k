import Foundation
import WatchConnectivity

/// The Watch app has no local database of its own, so this is its only
/// window into the iPhone app's actual workout history — see the matching
/// `PhoneConnectivityService` on the iPhone side.
@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {
    @Published private(set) var history: [WorkoutHistoryPayload] = []
    @Published private(set) var errorMessage: String?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func clearError() {
        errorMessage = nil
    }

    /// Called once when the Watch app appears. Applies whatever history the
    /// iPhone last delivered in the background via `applicationContext`
    /// (available immediately, even if the iPhone app isn't running right
    /// now), then opportunistically tries a live refresh over
    /// `sendMessage`. Unlike `pull()`/`push()` below, failures here stay
    /// silent — this is a passive background load on launch, not something
    /// the user asked for, so it shouldn't greet them with an error alert
    /// just because the iPhone app happens not to be reachable yet.
    func loadInitialHistory() async {
        guard WCSession.isSupported() else { return }
        applyContext(WCSession.default.receivedApplicationContext)
        await send(type: "requestHistory", surfaceErrors: false)
    }

    /// Fetches the iPhone app's current history as-is.
    func pull() async {
        await send(type: "requestHistory", surfaceErrors: true)
    }

    /// Asks the iPhone app to check HealthKit for anything new from this
    /// Watch right now, then fetches the (possibly updated) history that
    /// results — a more thorough "make sure everything's caught up" than a
    /// plain pull.
    func push() async {
        await send(type: "requestSync", surfaceErrors: true)
    }

    private func send(type: String, surfaceErrors: Bool) async {
        guard WCSession.default.activationState == .activated else {
            if surfaceErrors { errorMessage = L10n.watchConnectivityUnavailable }
            return
        }
        guard WCSession.default.isReachable else {
            if surfaceErrors { errorMessage = L10n.iphoneNotReachable }
            return
        }

        do {
            // Extract just the Data here, inside the reply closure (which
            // WCSession runs on an arbitrary background queue) — Data is
            // Sendable, but the raw [String: Any] reply dictionary isn't
            // guaranteed to be, so only the Data crosses the continuation
            // back into this MainActor-isolated function.
            let historyData: Data? = try await withCheckedThrowingContinuation { continuation in
                WCSession.default.sendMessage(
                    ["type": type],
                    replyHandler: { reply in
                        continuation.resume(returning: reply["history"] as? Data)
                    },
                    errorHandler: { error in
                        continuation.resume(throwing: error)
                    }
                )
            }
            guard let data = historyData else { return }
            applyHistoryData(data)
        } catch {
            if surfaceErrors { errorMessage = error.localizedDescription }
        }
    }

    private func applyContext(_ context: [String: Any]) {
        guard let data = context["history"] as? Data else { return }
        applyHistoryData(data)
    }

    private func applyHistoryData(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode([WorkoutHistoryPayload].self, from: data) else { return }
        history = decoded
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        // Extract just the Data (Sendable) before crossing into the
        // MainActor task, same reasoning as the reply-handling above —
        // `applicationContext` itself isn't guaranteed Sendable.
        guard let data = applicationContext["history"] as? Data else { return }
        Task { @MainActor [weak self] in
            self?.applyHistoryData(data)
        }
    }
}
