import Foundation
import SwiftData

@Model
final class WorkoutRecord {
    @Attribute(.unique) var id: UUID
    var weekNumber: Int
    var sessionDay: Int
    var sessionSummary: String
    var plannedDuration: TimeInterval
    var startedAt: Date
    var completedAt: Date
    var notes: String
    var distanceMeters: Double = 0
    var routeData: Data = Data()
    var workoutIdentifier: String = ""
    var displayTitle: String = ""

    init(
        id: UUID = UUID(),
        weekNumber: Int,
        sessionDay: Int,
        sessionSummary: String,
        plannedDuration: TimeInterval,
        startedAt: Date,
        completedAt: Date,
        distanceMeters: Double = 0,
        route: [RoutePoint] = [],
        workoutIdentifier: String = "",
        displayTitle: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.weekNumber = weekNumber
        self.sessionDay = sessionDay
        self.sessionSummary = sessionSummary
        self.plannedDuration = plannedDuration
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.distanceMeters = distanceMeters
        routeData = (try? JSONEncoder().encode(route)) ?? Data()
        self.workoutIdentifier = workoutIdentifier
        self.displayTitle = displayTitle
        self.notes = notes
    }

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

    var route: [RoutePoint] {
        guard !routeData.isEmpty else { return [] }
        return (try? JSONDecoder().decode([RoutePoint].self, from: routeData)) ?? []
    }
}
