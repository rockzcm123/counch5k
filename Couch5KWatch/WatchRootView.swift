import SwiftUI

struct WatchRootView: View {
    let plan: TrainingPlan

    @State private var history: [WorkoutHistoryEntry] = []
    @State private var isLoadingProgress = true

    private let healthService = HealthKitService()

    private var completedKeys: Set<String> {
        Set(history.map(\.completionKey))
    }

    var body: some View {
        TabView {
            nextWorkoutPage
            programPage
            historyPage
        }
        .task {
            try? await healthService.requestAuthorization()
            history = (try? await healthService.fetchWorkoutHistory()) ?? []
            isLoadingProgress = false
        }
    }

    private var nextWorkout: PlannedWorkout? {
        plan.nextWorkout(completedKeys: completedKeys)
    }

    private var nextWorkoutPage: some View {
        NavigationStack {
            VStack(spacing: 10) {
                if let workout = nextWorkout {
                    VStack(spacing: 4) {
                        Text(L10n.nextWorkout)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(workout.displayTitle)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text(workout.session.totalDuration.workoutDurationText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        WatchWorkoutView(weekNumber: workout.weekNumber, session: workout.session)
                    } label: {
                        Label(L10n.startWorkout, systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brandPink)
                } else if isLoadingProgress {
                    ProgressView()
                } else {
                    Text(L10n.planComplete)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle(L10n.appName)
        }
    }

    private var programPage: some View {
        NavigationStack {
            List(plan.weeks) { week in
                Section(L10n.weekTitle(week.number)) {
                    ForEach(week.sessions) { session in
                        let isComplete = completedKeys.contains("\(week.number)-\(session.day)")

                        NavigationLink {
                            WatchWorkoutView(
                                weekNumber: week.number,
                                session: session
                            )
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.title)
                                        .font(.headline)
                                    Text(session.summary)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                if isComplete {
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.planTitle)
        }
    }

    private var historyPage: some View {
        NavigationStack {
            Group {
                if isLoadingProgress {
                    ProgressView()
                } else if history.isEmpty {
                    Text(L10n.noHistory)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List(history) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.plannedWorkoutTitle(week: entry.weekNumber, day: entry.sessionDay))
                                .font(.headline)

                            HStack(spacing: 6) {
                                Text(entry.completedAt, format: .dateTime.month(.abbreviated).day())
                                if entry.distanceMeters > 0 {
                                    Text(String(format: "· %.2f km", entry.distanceMeters / 1_000))
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(L10n.historyTab)
        }
    }
}
