import Foundation

/// A lightweight, transferable mirror of `WorkoutRecord`, sent over
/// WatchConnectivity so the Watch app can display the iPhone app's actual
/// local history — not a HealthKit-derived approximation — with true
/// parity: same records (including custom workouts, which HealthKit has no
/// way to represent), same titles, same order.
struct WorkoutHistoryPayload: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let weekNumber: Int
    let sessionDay: Int
    let sessionSummary: String
    let plannedDuration: TimeInterval
    let startedAt: Date
    let completedAt: Date
    let distanceMeters: Double
    let workoutIdentifier: String
    let displayTitle: String

    var completionKey: String {
        workoutIdentifier.isEmpty ? "\(weekNumber)-\(sessionDay)" : workoutIdentifier
    }

    var title: String {
        displayTitle.isEmpty
            ? L10n.plannedWorkoutTitle(week: weekNumber, day: sessionDay)
            : displayTitle
    }

    var localizedSessionSummary: String {
        workoutIdentifier.isEmpty
            ? L10n.planSessionSummary(week: weekNumber, day: sessionDay)
            : sessionSummary
    }
}
