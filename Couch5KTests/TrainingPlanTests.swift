import XCTest
@testable import Couch5K

final class TrainingPlanTests: XCTestCase {
    private let plan = TrainingPlan.standard

    func testStandardPlanHasNineWeeksAndTwentySevenSessions() {
        XCTAssertEqual(plan.weeks.count, 9)
        XCTAssertEqual(plan.sessionCount, 27)
        XCTAssertTrue(plan.weeks.allSatisfy { $0.sessions.count == 3 })
    }

    func testEverySessionHasWarmupAndCooldown() {
        for session in plan.weeks.flatMap(\.sessions) {
            XCTAssertEqual(session.segments.first?.kind, .warmup)
            XCTAssertEqual(session.segments.first?.duration, 5 * 60)
            XCTAssertEqual(session.segments.last?.kind, .cooldown)
            XCTAssertEqual(session.segments.last?.duration, 5 * 60)
        }
    }

    func testAllSegmentsHavePositiveDurations() {
        for segment in plan.weeks.flatMap(\.sessions).flatMap(\.segments) {
            XCTAssertGreaterThan(segment.duration, 0)
        }
    }

    func testWeekOneContainsEightOneMinuteRuns() {
        let session = plan.weeks[0].sessions[0]
        let runs = session.segments.filter { $0.kind == .run }

        XCTAssertEqual(runs.count, 8)
        XCTAssertTrue(runs.allSatisfy { $0.duration == 60 })
        XCTAssertEqual(session.runningDuration, 8 * 60)
        XCTAssertEqual(session.totalDuration, 30 * 60)
    }

    func testWeekFiveProgressesToTwentyMinuteRun() {
        let week = plan.weeks[4]

        XCTAssertEqual(week.sessions.map(\.runningDuration), [15, 16, 20].map { TimeInterval($0 * 60) })
        XCTAssertEqual(
            week.sessions[2].segments.filter { $0.kind == .run }.map(\.duration),
            [20 * 60]
        )
    }

    func testWeekNineSessionsContainThirtyMinuteContinuousRun() {
        for session in plan.weeks[8].sessions {
            let runs = session.segments.filter { $0.kind == .run }
            XCTAssertEqual(runs.count, 1)
            XCTAssertEqual(runs[0].duration, 30 * 60)
            XCTAssertEqual(session.totalDuration, 40 * 60)
        }
    }
}
