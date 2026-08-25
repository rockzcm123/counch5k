import XCTest
@testable import Couch5K

final class ProgressTests: XCTestCase {
    private let plan = TrainingPlan.standard

    func testNextWorkoutStartsAtWeekOneDayOne() {
        let next = plan.nextWorkout(completedKeys: [])

        XCTAssertEqual(next?.weekNumber, 1)
        XCTAssertEqual(next?.session.day, 1)
    }

    func testNextWorkoutSkipsCompletedSessionsInPlanOrder() {
        let next = plan.nextWorkout(completedKeys: ["1-1", "1-2"])

        XCTAssertEqual(next?.completionKey, "1-3")
    }

    func testRepeatedCompletionKeysDoNotChangeProgress() {
        let keys = Set(["1-1", "1-1", "1-2"])

        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(plan.nextWorkout(completedKeys: keys)?.completionKey, "1-3")
    }

    func testNoNextWorkoutAfterCompletingPlan() {
        let allKeys = Set(plan.orderedWorkouts.map(\.completionKey))

        XCTAssertNil(plan.nextWorkout(completedKeys: allKeys))
    }

    func testStableWorkoutLookupUsesWeekAndDay() {
        let workout = plan.workout(weekNumber: 5, sessionDay: 3)

        XCTAssertEqual(workout?.completionKey, "5-3")
        XCTAssertEqual(workout?.session.runningDuration, 20 * 60)
    }

    func testCustomWorkoutBuildsExpectedSegments() {
        let workout = CustomWorkout(
            name: "短间歇",
            warmupSeconds: 120,
            runSeconds: 60,
            walkSeconds: 30,
            cycles: 3,
            cooldownSeconds: 90
        )
        let session = workout.trainingSession

        XCTAssertEqual(
            session.segments.map(\.kind),
            [.warmup, .run, .walk, .run, .walk, .run, .cooldown]
        )
        XCTAssertEqual(session.totalDuration, 120 + 60 + 30 + 60 + 30 + 60 + 90)
        XCTAssertEqual(session.runningDuration, 180)
    }

    func testCustomWorkoutHasStableIdentifier() {
        let id = UUID()
        let workout = CustomWorkout(
            id: id,
            name: "固定训练",
            warmupSeconds: 60,
            runSeconds: 60,
            walkSeconds: 60,
            cycles: 2,
            cooldownSeconds: 60
        )

        XCTAssertEqual(workout.workoutIdentifier, "custom-\(id.uuidString)")
    }

    @MainActor
    func testBackgroundLocationRequiresLocationMode() {
        XCTAssertFalse(
            WorkoutLocationService.supportsBackgroundLocation(
                infoDictionary: nil
            )
        )
        XCTAssertFalse(
            WorkoutLocationService.supportsBackgroundLocation(
                infoDictionary: ["UIBackgroundModes": ["audio"]]
            )
        )
        XCTAssertTrue(
            WorkoutLocationService.supportsBackgroundLocation(
                infoDictionary: ["UIBackgroundModes": ["audio", "location"]]
            )
        )
    }

    @MainActor
    func testLocationServiceStartsWithoutBackgroundAssertion() {
        let service = WorkoutLocationService()

        service.start()
        _ = service.stop()

        XCTAssertTrue(
            WorkoutLocationService.supportsBackgroundLocation(
                infoDictionary: Bundle.main.infoDictionary
            )
        )
    }
}
