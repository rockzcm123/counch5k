import SwiftUI

struct WatchRootView: View {
    let plan: TrainingPlan

    @State private var completedKeys: Set<String> = []
    @State private var isLoadingProgress = true

    private let healthService = HealthKitService()

    var body: some View {
        TabView {
            nextWorkoutPage
            programPage
        }
        .task {
            try? await healthService.requestAuthorization()
            completedKeys = (try? await healthService.fetchCompletedPlanSessionKeys()) ?? []
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
}
