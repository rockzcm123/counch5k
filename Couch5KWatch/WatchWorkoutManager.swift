@preconcurrency import HealthKit
import Foundation

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var errorMessage: String?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    func start(at date: Date = .now) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WatchWorkoutError.healthDataUnavailable
        }

        let workoutType = HKObjectType.workoutType()
        let heartRateType = HKQuantityType(.heartRate)
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        try await healthStore.requestAuthorization(
            toShare: [workoutType, distanceType],
            read: [heartRateType, distanceType]
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
    }

    func pause() {
        session?.pause()
    }

    func resume() {
        session?.resume()
    }

    func finish(at date: Date = .now) {
        session?.end()
        guard let builder else { return }

        builder.endCollection(withEnd: date) { [weak self] success, error in
            if let error {
                let message = error.localizedDescription
                Task { @MainActor [weak self, message] in
                    self?.errorMessage = message
                }
                return
            }
            guard success else { return }
            guard let manager = self else { return }
            builder.finishWorkout { [weak manager] _, error in
                if let error {
                    let message = error.localizedDescription
                    Task { @MainActor [weak manager, message] in
                        manager?.errorMessage = message
                    }
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
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(heartRateType),
              let statistics = workoutBuilder.statistics(for: heartRateType),
              let quantity = statistics.mostRecentQuantity() else {
            return
        }
        let value = quantity.doubleValue(
            for: HKUnit.count().unitDivided(by: .minute())
        )
        Task { @MainActor [weak self] in
            self?.heartRate = value
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
