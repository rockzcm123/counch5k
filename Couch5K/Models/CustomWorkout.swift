import Foundation
import SwiftData

@Model
final class CustomWorkout {
    @Attribute(.unique) var id: UUID
    var name: String
    var warmupSeconds: Int
    var runSeconds: Int
    var walkSeconds: Int
    var cycles: Int
    var cooldownSeconds: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        warmupSeconds: Int,
        runSeconds: Int,
        walkSeconds: Int,
        cycles: Int,
        cooldownSeconds: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.warmupSeconds = warmupSeconds
        self.runSeconds = runSeconds
        self.walkSeconds = walkSeconds
        self.cycles = cycles
        self.cooldownSeconds = cooldownSeconds
        self.createdAt = createdAt
    }

    var trainingSession: TrainingSession {
        var segments: [WorkoutSegment] = []
        for cycle in 0..<cycles {
            segments.append(WorkoutSegment(kind: .run, duration: TimeInterval(runSeconds)))
            if cycle < cycles - 1 {
                segments.append(WorkoutSegment(kind: .walk, duration: TimeInterval(walkSeconds)))
            }
        }

        return TrainingSession(
            day: 1,
            summary: summary,
            mainSegments: segments,
            warmupDuration: TimeInterval(warmupSeconds),
            cooldownDuration: TimeInterval(cooldownSeconds)
        )
    }

    var summary: String {
        L10n.customWorkoutSummary(
            runSeconds: runSeconds,
            walkSeconds: walkSeconds,
            cycles: cycles
        )
    }

    var workoutIdentifier: String { "custom-\(id.uuidString)" }

}
