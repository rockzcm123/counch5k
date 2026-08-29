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

    /// Fetches the iPhone app's current history as-is.
    func pull() async {
        await send(type: "requestHistory")
    }

    /// Asks the iPhone app to check HealthKit for anything new from this
    /// Watch right now, then fetches the (possibly updated) history that
    /// results — a more thorough "make sure everything's caught up" than a
    /// plain pull.
    func push() async {
        await send(type: "requestSync")
    }

    private func send(type: String) async {
        guard WCSession.default.activationState == .activated else {
            errorMessage = L10n.watchConnectivityUnavailable
            return
        }
        guard WCSession.default.isReachable else {
            errorMessage = L10n.iphoneNotReachable
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
            if let decoded = try? JSONDecoder().decode([WorkoutHistoryPayload].self, from: data) {
                history = decoded
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}
}
