@preconcurrency import HealthKit
import Foundation

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var errorMessage: String?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    func start(weekNumber: Int, sessionDay: Int, at date: Date = .now) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WatchWorkoutError.healthDataUnavailable
        }

        let workoutType = HKObjectType.workoutType()
        let heartRateType = HKQuantityType(.heartRate)
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        try await healthStore.requestAuthorization(
            toShare: [workoutType, distanceType],
            read: [heartRateType, distanceType, workoutType]
        )

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        let session = try HKWorkoutSession(
            healthStore: healthStore,
            configuration: configuration
        )
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )
        session.delegate = self
        builder.delegate = self
        self.session = session
        self.builder = builder

        session.startActivity(with: date)
        try await beginCollection(builder, at: date)
        // Tags this workout so the iPhone app can find and reconcile it into
        // its own local history — see HealthKitService.fetchUnsyncedWatchWorkouts.
        try await addMetadata(
            [
                "Couch5KWatchWorkout": true,
                "Couch5KWeekNumber": weekNumber,
                "Couch5KSessionDay": sessionDay
            ],
            to: builder
        )
    }

    func pause() {
        session?.pause()
    }

    func resume() {
        session?.resume()
    }

    func clearError() {
        errorMessage = nil
    }

    /// Ends the session and commits the workout to HealthKit, awaiting
    /// confirmation that it actually landed before returning — callers rely
    /// on this to know it's safe to dismiss (the Watch has no local history
    /// store, so an incomplete commit would otherwise lose the run).
    /// Failures are still routed through `errorMessage`, not thrown, to
    /// match this class's existing error-handling convention.
    func finish(at date: Date = .now) async {
        session?.end()
        guard let builder else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            builder.endCollection(withEnd: date) { [weak self] success, error in
                if let error {
                    let message = error.localizedDescription
                    Task { @MainActor [weak self, message] in
                        self?.errorMessage = message
                    }
                    continuation.resume()
                    return
                }
                guard success, let self else {
                    continuation.resume()
                    return
                }
                builder.finishWorkout { [weak self] _, error in
                    if let error {
                        let message = error.localizedDescription
                        Task { @MainActor [weak self, message] in
                            self?.errorMessage = message
                        }
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func beginCollection(
        _ builder: HKLiveWorkoutBuilder,
        at date: Date
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: date) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: WatchWorkoutError.collectionFailed)
                }
            }
        }
    }

    private func addMetadata(
        _ metadata: [String: Any],
        to builder: HKLiveWorkoutBuilder
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.addMetadata(metadata) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: WatchWorkoutError.collectionFailed)
                }
            }
        }
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.errorMessage = error.localizedDescription
        }
    }
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
           collectedTypes.contains(heartRateType),
           let statistics = workoutBuilder.statistics(for: heartRateType),
           let quantity = statistics.mostRecentQuantity() {
            let value = quantity.doubleValue(
                for: HKUnit.count().unitDivided(by: .minute())
            )
            Task { @MainActor [weak self] in
                self?.heartRate = value
            }
        }

        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
           collectedTypes.contains(distanceType),
           let statistics = workoutBuilder.statistics(for: distanceType),
           let sum = statistics.sumQuantity() {
            let meters = sum.doubleValue(for: .meter())
            Task { @MainActor [weak self] in
                self?.distanceMeters = meters
            }
        }
    }
}

enum WatchWorkoutError: LocalizedError {
    case healthDataUnavailable
    case collectionFailed

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable: "Apple Watch 无法使用健康数据。"
        case .collectionFailed: "无法开始记录训练。"
        }
    }
}
