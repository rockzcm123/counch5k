import Foundation

struct ActiveWorkoutSnapshot: Codable, Equatable, Sendable {
    let weekNumber: Int
    let sessionDay: Int
    let state: WorkoutEngine.State
    let segmentIndex: Int
    let segmentRemaining: TimeInterval
    let savedAt: Date
    let workoutStartedAt: Date
    let distanceMeters: Double
    let route: [RoutePoint]
    let workoutIdentifier: String?
    let workoutName: String?
    let customSession: TrainingSession?

    init(
        weekNumber: Int,
        sessionDay: Int,
        state: WorkoutEngine.State,
        segmentIndex: Int,
        segmentRemaining: TimeInterval,
        savedAt: Date,
        workoutStartedAt: Date,
        distanceMeters: Double = 0,
        route: [RoutePoint] = [],
        workoutIdentifier: String? = nil,
        workoutName: String? = nil,
        customSession: TrainingSession? = nil
    ) {
        self.weekNumber = weekNumber
        self.sessionDay = sessionDay
        self.state = state
        self.segmentIndex = segmentIndex
        self.segmentRemaining = segmentRemaining
        self.savedAt = savedAt
        self.workoutStartedAt = workoutStartedAt
        self.distanceMeters = distanceMeters
        self.route = route
        self.workoutIdentifier = workoutIdentifier
        self.workoutName = workoutName
        self.customSession = customSession
    }
}

@MainActor
final class ActiveWorkoutStore: ObservableObject {
    @Published private(set) var snapshot: ActiveWorkoutSnapshot?

    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard, key: String = "activeWorkoutSnapshot") {
        self.defaults = defaults
        self.key = key
        load()
    }

    func save(_ snapshot: ActiveWorkoutSnapshot) {
        do {
            defaults.set(try encoder.encode(snapshot), forKey: key)
            self.snapshot = snapshot
        } catch {
            assertionFailure("Unable to save active workout: \(error)")
        }
    }

    func clear() {
        defaults.removeObject(forKey: key)
        snapshot = nil
    }

    private func load() {
        guard let data = defaults.data(forKey: key) else {
            snapshot = nil
            return
        }

        do {
            snapshot = try decoder.decode(ActiveWorkoutSnapshot.self, from: data)
        } catch {
            defaults.removeObject(forKey: key)
            snapshot = nil
            assertionFailure("Unable to restore active workout: \(error)")
        }
    }
}
