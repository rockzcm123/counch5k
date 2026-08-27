import CoreLocation
import Foundation
import HealthKit

enum HealthKitServiceError: LocalizedError {
    case unavailable
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .unavailable: L10n.healthUnavailable
        case .authorizationDenied: L10n.healthAuthorizationDenied
        }
    }
}

/// A plan workout completed on Apple Watch, reconstructed from the
/// Couch5K-specific metadata the Watch app attaches to its HealthKit
/// workouts, so the iPhone app can catch up its own local history.
struct ReconciledWorkout: Sendable {
    let healthKitWorkoutID: String
    let weekNumber: Int
    let sessionDay: Int
    let startedAt: Date
    let completedAt: Date
    let distanceMeters: Double
}

actor HealthKitService {
    private let healthStore = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.unavailable
        }

        let workoutType = HKObjectType.workoutType()
        let routeType = HKSeriesType.workoutRoute()
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let energyType = HKQuantityType(.activeEnergyBurned)
        try await healthStore.requestAuthorization(
            toShare: [workoutType, routeType, distanceType, energyType],
            read: [workoutType, distanceType]
        )
    }

    /// Finds Couch5K plan workouts recorded in HealthKit (i.e. completed on
    /// Apple Watch) that aren't already reflected in the app's own local
    /// history, identified by the Couch5K-specific metadata the Watch app
    /// attaches. `existingIDs` should be every non-empty
    /// `WorkoutRecord.healthKitWorkoutID` already stored locally.
    func fetchUnsyncedWatchWorkouts(excluding existingIDs: Set<String>) async throws -> [ReconciledWorkout] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.unavailable
        }

        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .running)

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
                }
            }
            healthStore.execute(query)
        }

        return workouts.compactMap { workout in
            guard workout.metadata?["Couch5KWatchWorkout"] as? Bool == true,
                  let weekNumber = workout.metadata?["Couch5KWeekNumber"] as? Int,
                  let sessionDay = workout.metadata?["Couch5KSessionDay"] as? Int else {
                return nil
            }

            let healthKitWorkoutID = workout.uuid.uuidString
            guard !existingIDs.contains(healthKitWorkoutID) else { return nil }

            return ReconciledWorkout(
                healthKitWorkoutID: healthKitWorkoutID,
                weekNumber: weekNumber,
                sessionDay: sessionDay,
                startedAt: workout.startDate,
                completedAt: workout.endDate,
                distanceMeters: workout.totalDistance?.doubleValue(for: .meter()) ?? 0
            )
        }
    }

    func saveWorkout(_ result: WorkoutResult) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.unavailable
        }
        guard healthStore.authorizationStatus(for: HKObjectType.workoutType()) != .sharingDenied else {
            throw HealthKitServiceError.authorizationDenied
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )

        try await beginCollection(builder, at: result.startedAt)
        try await addMetadata(
            [
                HKMetadataKeyIndoorWorkout: false,
                "Couch5KWorkout": true
            ],
            to: builder
        )

        var samples: [HKQuantitySample] = []

        if result.distanceMeters > 0 {
            let distanceType = HKQuantityType(.distanceWalkingRunning)
            samples.append(
                HKQuantitySample(
                    type: distanceType,
                    quantity: HKQuantity(unit: .meter(), doubleValue: result.distanceMeters),
                    start: result.startedAt,
                    end: result.completedAt
                )
            )
        }

        if let energyKilocalories = estimatedActiveEnergy(for: result), energyKilocalories > 0 {
            let energyType = HKQuantityType(.activeEnergyBurned)
            samples.append(
                HKQuantitySample(
                    type: energyType,
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: energyKilocalories),
                    start: result.startedAt,
                    end: result.completedAt
                )
            )
        }

        if !samples.isEmpty {
            try await addSamples(samples, to: builder)
        }

        try await endCollection(builder, at: result.completedAt)
        let workout = try await finishWorkout(builder)
        guard !result.route.isEmpty else { return }

        let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
        try await insert(result.route.map(\.location), into: routeBuilder)
        try await finish(routeBuilder, workout: workout)
    }

    /// Estimates calories burned using a fixed run-walk MET value and the
    /// weight from the About Me profile (falls back to 70kg when unset),
    /// since this app has no heart-rate sensor to measure it directly.
    private func estimatedActiveEnergy(for result: WorkoutResult) -> Double? {
        let hours = result.completedAt.timeIntervalSince(result.startedAt) / 3_600
        guard hours > 0 else { return nil }

        let storedWeightKg = UserDefaults.standard.double(forKey: "profileWeightKg")
        let weightKg = storedWeightKg > 0 ? storedWeightKg : 70
        let runWalkMET = 7.0
        return runWalkMET * weightKg * hours
    }

    private func beginCollection(
        _ builder: HKWorkoutBuilder,
        at date: Date
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: date) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitServiceError.unavailable)
                }
            }
        }
    }

    private func addMetadata(
        _ metadata: [String: Any],
        to builder: HKWorkoutBuilder
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.addMetadata(metadata) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitServiceError.unavailable)
                }
            }
        }
    }

    private func addSamples(
        _ samples: [HKSample],
        to builder: HKWorkoutBuilder
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add(samples) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitServiceError.unavailable)
                }
            }
        }
    }

    private func endCollection(
        _ builder: HKWorkoutBuilder,
        at date: Date
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: date) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitServiceError.unavailable)
                }
            }
        }
    }

    private func finishWorkout(_ builder: HKWorkoutBuilder) async throws -> HKWorkout {
        try await withCheckedThrowingContinuation { continuation in
            builder.finishWorkout { workout, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let workout {
                    continuation.resume(returning: workout)
                } else {
                    continuation.resume(throwing: HealthKitServiceError.unavailable)
                }
            }
        }
    }

    private func insert(
        _ locations: [CLLocation],
        into builder: HKWorkoutRouteBuilder
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.insertRouteData(locations) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitServiceError.unavailable)
                }
            }
        }
    }

    private func finish(
        _ builder: HKWorkoutRouteBuilder,
        workout: HKWorkout
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.finishRoute(with: workout, metadata: nil) { route, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if route != nil {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitServiceError.unavailable)
                }
            }
        }
    }
}
