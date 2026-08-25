import XCTest
@testable import Couch5K

@MainActor
final class WorkoutEngineTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testStartAndTimestampUpdate() {
        let engine = WorkoutEngine(session: testSession)

        engine.start(at: start)
        engine.update(at: start.addingTimeInterval(12))

        XCTAssertEqual(engine.state, .running)
        XCTAssertEqual(engine.segmentRemaining, 18)
        XCTAssertEqual(engine.totalRemaining, 48)
    }

    func testUpdateAdvancesAcrossMultipleSegments() {
        let engine = WorkoutEngine(session: testSession)

        engine.start(at: start)
        engine.update(at: start.addingTimeInterval(35))

        XCTAssertEqual(engine.segmentIndex, 1)
        XCTAssertEqual(engine.currentSegment?.kind, .run)
        XCTAssertEqual(engine.segmentRemaining, 5)
        XCTAssertEqual(engine.totalRemaining, 25)
    }

    func testPauseStopsElapsedTimeUntilResume() {
        let engine = WorkoutEngine(session: testSession)

        engine.start(at: start)
        engine.pause(at: start.addingTimeInterval(10))
        engine.update(at: start.addingTimeInterval(100))

        XCTAssertEqual(engine.state, .paused)
        XCTAssertEqual(engine.segmentRemaining, 20)

        engine.resume(at: start.addingTimeInterval(100))
        engine.update(at: start.addingTimeInterval(105))

        XCTAssertEqual(engine.segmentRemaining, 15)
    }

    func testSkipMovesToNextSegmentAndPreservesPausedState() {
        let engine = WorkoutEngine(session: testSession)

        engine.start(at: start)
        engine.pause(at: start.addingTimeInterval(5))
        engine.skip(at: start.addingTimeInterval(5))

        XCTAssertEqual(engine.state, .paused)
        XCTAssertEqual(engine.segmentIndex, 1)
        XCTAssertEqual(engine.segmentRemaining, 10)
    }

    func testWorkoutCompletesAtEnd() {
        let engine = WorkoutEngine(session: testSession)

        engine.start(at: start)
        engine.update(at: start.addingTimeInterval(61))

        XCTAssertEqual(engine.state, .completed)
        XCTAssertEqual(engine.segmentRemaining, 0)
        XCTAssertEqual(engine.totalRemaining, 0)
        XCTAssertEqual(engine.progress, 1)
    }

    func testRunningSnapshotRestoresElapsedTime() {
        let engine = WorkoutEngine(session: testSession)
        engine.start(at: start)
        let snapshot = engine.snapshot(
            weekNumber: 1,
            at: start.addingTimeInterval(10)
        )

        let restored = WorkoutEngine(
            session: testSession,
            snapshot: try! XCTUnwrap(snapshot),
            now: start.addingTimeInterval(35)
        )

        XCTAssertEqual(restored.state, .running)
        XCTAssertEqual(restored.segmentIndex, 1)
        XCTAssertEqual(restored.segmentRemaining, 5)
    }

    func testPausedSnapshotDoesNotConsumeElapsedTime() throws {
        let engine = WorkoutEngine(session: testSession)
        engine.start(at: start)
        engine.pause(at: start.addingTimeInterval(10))
        let snapshot = try XCTUnwrap(
            engine.snapshot(weekNumber: 1, at: start.addingTimeInterval(10))
        )

        let restored = WorkoutEngine(
            session: testSession,
            snapshot: snapshot,
            now: start.addingTimeInterval(100)
        )

        XCTAssertEqual(restored.state, .paused)
        XCTAssertEqual(restored.segmentRemaining, 20)
    }

    func testSnapshotRestoredAfterPlannedEndCompletesWorkout() throws {
        let engine = WorkoutEngine(session: testSession)
        engine.start(at: start)
        let snapshot = try XCTUnwrap(
            engine.snapshot(weekNumber: 1, at: start.addingTimeInterval(5))
        )

        let restored = WorkoutEngine(
            session: testSession,
            snapshot: snapshot,
            now: start.addingTimeInterval(100)
        )

        XCTAssertEqual(restored.state, .completed)
        XCTAssertEqual(restored.totalRemaining, 0)
    }

    func testSnapshotPreservesCustomWorkoutAndRoute() throws {
        let engine = WorkoutEngine(session: testSession)
        engine.start(at: start)
        let point = RoutePoint(
            latitude: 22.3193,
            longitude: 114.1694,
            altitude: 5,
            timestamp: start
        )
        let snapshot = try XCTUnwrap(
            engine.snapshot(
                weekNumber: 0,
                distanceMeters: 123,
                route: [point],
                workoutIdentifier: "custom-test",
                workoutName: "测试间歇",
                at: start.addingTimeInterval(5)
            )
        )

        XCTAssertEqual(snapshot.distanceMeters, 123)
        XCTAssertEqual(snapshot.route, [point])
        XCTAssertEqual(snapshot.workoutIdentifier, "custom-test")
        XCTAssertEqual(snapshot.workoutName, "测试间歇")
        XCTAssertEqual(snapshot.customSession?.summary, "测试训练")
        XCTAssertEqual(
            snapshot.customSession?.segments.map(\.duration),
            [30, 10, 20]
        )
    }

    func testFinishLineEncouragementCoversShortRunAtLastTwentyPercent() {
        XCTAssertFalse(
            WorkoutEncouragementPolicy.shouldOfferFinishLine(
                kind: .run,
                duration: 60,
                remaining: 13
            )
        )
        XCTAssertTrue(
            WorkoutEncouragementPolicy.shouldOfferFinishLine(
                kind: .run,
                duration: 60,
                remaining: 12
            )
        )
    }

    func testFinishLineEncouragementCapsLongRunAtNinetySeconds() {
        XCTAssertFalse(
            WorkoutEncouragementPolicy.shouldOfferFinishLine(
                kind: .run,
                duration: 30 * 60,
                remaining: 91
            )
        )
        XCTAssertTrue(
            WorkoutEncouragementPolicy.shouldOfferFinishLine(
                kind: .run,
                duration: 30 * 60,
                remaining: 90
            )
        )
    }

    func testEncouragementDoesNotTriggerDuringWalk() {
        XCTAssertFalse(
            WorkoutEncouragementPolicy.shouldOfferMidpoint(
                kind: .walk,
                duration: 5 * 60,
                remaining: 2 * 60
            )
        )
        XCTAssertFalse(
            WorkoutEncouragementPolicy.shouldOfferFinishLine(
                kind: .walk,
                duration: 60,
                remaining: 5
            )
        )
    }

    func testMidpointEncouragementDoesNotCompeteWithFinishLineCue() {
        XCTAssertTrue(
            WorkoutEncouragementPolicy.shouldOfferMidpoint(
                kind: .run,
                duration: 10 * 60,
                remaining: 5 * 60
            )
        )
        XCTAssertFalse(
            WorkoutEncouragementPolicy.shouldOfferMidpoint(
                kind: .run,
                duration: 10 * 60,
                remaining: 60
            )
        )
    }

    private var testSession: TrainingSession {
        TrainingSession(
            day: 1,
            summary: "测试训练",
            mainSegments: [WorkoutSegment(kind: .run, duration: 10)],
            warmupDuration: 30,
            cooldownDuration: 20
        )
    }
}
