import Foundation

enum SegmentKind: String, Codable, Hashable, Sendable {
    case warmup
    case run
    case walk
    case cooldown

    var title: String {
        L10n.segmentTitle(self)
    }

    var systemImage: String {
        switch self {
        case .warmup: "figure.walk.motion"
        case .run: "figure.run"
        case .walk: "figure.walk"
        case .cooldown: "wind"
        }
    }
}

struct WorkoutSegment: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let kind: SegmentKind
    let duration: TimeInterval

    init(id: UUID = UUID(), kind: SegmentKind, duration: TimeInterval) {
        self.id = id
        self.kind = kind
        self.duration = duration
    }
}

struct TrainingSession: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let day: Int
    let summary: String
    let segments: [WorkoutSegment]

    init(
        id: UUID = UUID(),
        day: Int,
        summary: String,
        mainSegments: [WorkoutSegment],
        warmupDuration: TimeInterval = 5 * 60,
        cooldownDuration: TimeInterval = 5 * 60
    ) {
        self.id = id
        self.day = day
        self.summary = summary
        segments = [
            WorkoutSegment(kind: .warmup, duration: warmupDuration)
        ] + mainSegments + [
            WorkoutSegment(kind: .cooldown, duration: cooldownDuration)
        ]
    }

    var title: String { L10n.sessionTitle(day) }
    var totalDuration: TimeInterval { segments.reduce(0) { $0 + $1.duration } }
    var runningDuration: TimeInterval {
        segments.filter { $0.kind == .run }.reduce(0) { $0 + $1.duration }
    }
}

struct TrainingWeek: Identifiable, Codable, Hashable, Sendable {
    let number: Int
    let focus: String
    let sessions: [TrainingSession]

    var id: Int { number }
}

struct TrainingPlan: Codable, Hashable, Sendable {
    let title: String
    let weeks: [TrainingWeek]

    var sessionCount: Int { weeks.reduce(0) { $0 + $1.sessions.count } }

    var orderedWorkouts: [PlannedWorkout] {
        weeks.flatMap { week in
            week.sessions.map {
                PlannedWorkout(weekNumber: week.number, session: $0)
            }
        }
    }

    func workout(weekNumber: Int, sessionDay: Int) -> PlannedWorkout? {
        orderedWorkouts.first {
            $0.weekNumber == weekNumber && $0.session.day == sessionDay
        }
    }

    func nextWorkout(completedKeys: Set<String>) -> PlannedWorkout? {
        orderedWorkouts.first { !completedKeys.contains($0.completionKey) }
    }
}

struct PlannedWorkout: Identifiable, Hashable, Sendable {
    let weekNumber: Int
    let session: TrainingSession
    let customName: String?
    let customIdentifier: String?

    init(
        weekNumber: Int,
        session: TrainingSession,
        customName: String? = nil,
        customIdentifier: String? = nil
    ) {
        self.weekNumber = weekNumber
        self.session = session
        self.customName = customName
        self.customIdentifier = customIdentifier
    }

    var id: String { completionKey }
    var completionKey: String { customIdentifier ?? "\(weekNumber)-\(session.day)" }
    var displayTitle: String {
        customName ?? L10n.plannedWorkoutTitle(week: weekNumber, day: session.day)
    }
}

extension TrainingPlan {
    static var standard: TrainingPlan {
        TrainingPlan(
        title: L10n.planTitle,
        weeks: [
            week(
                1,
                focus: L10n.weekFocus(1),
                sessions: identicalSessions(
                    week: 1,
                    segments: repeated([run(1), walk(seconds: 90)], count: 8)
                )
            ),
            week(
                2,
                focus: L10n.weekFocus(2),
                sessions: identicalSessions(
                    week: 2,
                    segments: repeated([run(seconds: 90), walk(2)], count: 6)
                )
            ),
            week(
                3,
                focus: L10n.weekFocus(3),
                sessions: identicalSessions(
                    week: 3,
                    segments: repeated(
                        [run(seconds: 90), walk(seconds: 90), run(3), walk(3)],
                        count: 2
                    )
                )
            ),
            week(
                4,
                focus: L10n.weekFocus(4),
                sessions: identicalSessions(
                    week: 4,
                    segments: [
                        run(3), walk(seconds: 90),
                        run(5), walk(seconds: 150),
                        run(3), walk(seconds: 90),
                        run(5)
                    ]
                )
            ),
            week(
                5,
                focus: L10n.weekFocus(5),
                sessions: [
                    session(week: 5, day: 1, [
                        run(5), walk(3), run(5), walk(3), run(5)
                    ]),
                    session(week: 5, day: 2, [
                        run(8), walk(5), run(8)
                    ]),
                    session(week: 5, day: 3, [run(20)])
                ]
            ),
            week(
                6,
                focus: L10n.weekFocus(6),
                sessions: [
                    session(week: 6, day: 1, [
                        run(5), walk(3), run(8), walk(3), run(5)
                    ]),
                    session(week: 6, day: 2, [
                        run(10), walk(3), run(10)
                    ]),
                    session(week: 6, day: 3, [run(25)])
                ]
            ),
            week(
                7,
                focus: L10n.weekFocus(7),
                sessions: identicalSessions(
                    week: 7,
                    segments: [run(25)]
                )
            ),
            week(
                8,
                focus: L10n.weekFocus(8),
                sessions: identicalSessions(
                    week: 8,
                    segments: [run(28)]
                )
            ),
            week(
                9,
                focus: L10n.weekFocus(9),
                sessions: identicalSessions(
                    week: 9,
                    segments: [run(30)]
                )
            )
        ]
    )
    }

    private static func week(
        _ number: Int,
        focus: String,
        sessions: [TrainingSession]
    ) -> TrainingWeek {
        TrainingWeek(number: number, focus: focus, sessions: sessions)
    }

    private static func identicalSessions(
        week: Int,
        segments: [WorkoutSegment]
    ) -> [TrainingSession] {
        (1...3).map { session(week: week, day: $0, segments) }
    }

    private static func session(
        week: Int,
        day: Int,
        _ segments: [WorkoutSegment]
    ) -> TrainingSession {
        TrainingSession(
            day: day,
            summary: L10n.planSessionSummary(week: week, day: day),
            mainSegments: segments
        )
    }

    private static func repeated(
        _ segments: [WorkoutSegment],
        count: Int
    ) -> [WorkoutSegment] {
        (0..<count).flatMap { _ in segments.map { WorkoutSegment(kind: $0.kind, duration: $0.duration) } }
    }

    private static func run(_ minutes: Double) -> WorkoutSegment {
        WorkoutSegment(kind: .run, duration: minutes * 60)
    }

    private static func run(seconds: Double) -> WorkoutSegment {
        WorkoutSegment(kind: .run, duration: seconds)
    }

    private static func walk(_ minutes: Double) -> WorkoutSegment {
        WorkoutSegment(kind: .walk, duration: minutes * 60)
    }

    private static func walk(seconds: Double) -> WorkoutSegment {
        WorkoutSegment(kind: .walk, duration: seconds)
    }
}

extension TimeInterval {
    var workoutDurationText: String {
        let totalMinutes = Int(self) / 60
        let seconds = Int(self) % 60
        return L10n.duration(totalMinutes * 60 + seconds)
    }
}
