import Combine
import Foundation

@MainActor
final class WorkoutEngine: ObservableObject {
    enum State: String, Codable, Equatable {
        case ready
        case running
        case paused
        case completed
    }

    let session: TrainingSession

    @Published private(set) var state: State = .ready
    @Published private(set) var segmentIndex = 0
    @Published private(set) var segmentRemaining: TimeInterval
    @Published private(set) var totalRemaining: TimeInterval
    @Published private(set) var workoutStartedAt: Date?

    private var segmentStartedAt: Date?
    private var remainingAtStart: TimeInterval

    init(session: TrainingSession) {
        self.session = session
        let firstDuration = session.segments.first?.duration ?? 0
        segmentRemaining = firstDuration
        remainingAtStart = firstDuration
        totalRemaining = session.totalDuration
        workoutStartedAt = nil
    }

    init(session: TrainingSession, snapshot: ActiveWorkoutSnapshot, now: Date = .now) {
        self.session = session
        segmentIndex = snapshot.segmentIndex
        segmentRemaining = snapshot.segmentRemaining
        remainingAtStart = snapshot.segmentRemaining
        totalRemaining = 0
        workoutStartedAt = snapshot.workoutStartedAt
        state = snapshot.state
        segmentStartedAt = snapshot.state == .running ? snapshot.savedAt : nil

        guard session.segments.indices.contains(segmentIndex), remainingAtStart > 0 else {
            segmentIndex = session.segments.count
            segmentRemaining = 0
            remainingAtStart = 0
            totalRemaining = 0
            state = .completed
            segmentStartedAt = nil
            return
        }

        recalculateTotalRemaining()
        update(at: now)
    }

    var currentSegment: WorkoutSegment? {
        guard session.segments.indices.contains(segmentIndex) else { return nil }
        return session.segments[segmentIndex]
    }

    var nextSegment: WorkoutSegment? {
        let nextIndex = segmentIndex + 1
        guard session.segments.indices.contains(nextIndex) else { return nil }
        return session.segments[nextIndex]
    }

    var progress: Double {
        guard session.totalDuration > 0 else { return 1 }
        return min(max(1 - totalRemaining / session.totalDuration, 0), 1)
    }

    func start(at date: Date = .now) {
        guard state == .ready, currentSegment != nil else { return }
        segmentStartedAt = date
        remainingAtStart = segmentRemaining
        workoutStartedAt = date
        state = .running
    }

    func pause(at date: Date = .now) {
        guard state == .running else { return }
        update(at: date)
        guard state == .running else { return }
        segmentStartedAt = nil
        remainingAtStart = segmentRemaining
        state = .paused
    }

    func resume(at date: Date = .now) {
        guard state == .paused else { return }
        segmentStartedAt = date
        remainingAtStart = segmentRemaining
        state = .running
    }

    func skip(at date: Date = .now) {
        guard state == .running || state == .paused else { return }
        advanceSegment(at: date, overflow: 0)
    }

    func update(at date: Date = .now) {
        guard state == .running, let segmentStartedAt else { return }

        var elapsed = max(date.timeIntervalSince(segmentStartedAt), 0)
        while state == .running, elapsed >= remainingAtStart {
            elapsed -= remainingAtStart
            advanceSegment(at: date.addingTimeInterval(-elapsed), overflow: 0)
        }

        guard state == .running else { return }
        segmentRemaining = max(remainingAtStart - elapsed, 0)
        recalculateTotalRemaining()
    }

    func snapshot(
        weekNumber: Int,
        distanceMeters: Double = 0,
        route: [RoutePoint] = [],
        workoutIdentifier: String? = nil,
        workoutName: String? = nil,
        at date: Date = .now
    ) -> ActiveWorkoutSnapshot? {
        guard state == .running || state == .paused, let workoutStartedAt else { return nil }
        update(at: date)
        guard state == .running || state == .paused else { return nil }

        return ActiveWorkoutSnapshot(
            weekNumber: weekNumber,
            sessionDay: session.day,
            state: state,
            segmentIndex: segmentIndex,
            segmentRemaining: segmentRemaining,
            savedAt: date,
            workoutStartedAt: workoutStartedAt,
            distanceMeters: distanceMeters,
            route: route,
            workoutIdentifier: workoutIdentifier,
            workoutName: workoutName,
            customSession: workoutIdentifier == nil ? nil : session
        )
    }

    private func advanceSegment(at date: Date, overflow: TimeInterval) {
        let wasPaused = state == .paused
        let nextIndex = segmentIndex + 1

        guard session.segments.indices.contains(nextIndex) else {
            segmentIndex = session.segments.count
            segmentRemaining = 0
            totalRemaining = 0
            segmentStartedAt = nil
            remainingAtStart = 0
            state = .completed
            return
        }

        segmentIndex = nextIndex
        let duration = session.segments[nextIndex].duration
        segmentRemaining = max(duration - overflow, 0)
        remainingAtStart = segmentRemaining
        segmentStartedAt = wasPaused ? nil : date
        recalculateTotalRemaining()
    }

    private func recalculateTotalRemaining() {
        guard currentSegment != nil else {
            totalRemaining = 0
            return
        }

        let laterDuration = session.segments
            .dropFirst(segmentIndex + 1)
            .reduce(0) { $0 + $1.duration }
        totalRemaining = segmentRemaining + laterDuration
    }
}
