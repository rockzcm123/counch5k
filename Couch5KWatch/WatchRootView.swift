import SwiftUI
import WatchKit

struct WatchRootView: View {
    let plan: TrainingPlan

    @StateObject private var connectivity = WatchConnectivityService()
    @State private var isLoadingProgress = true

    private var completedKeys: Set<String> {
        Set(connectivity.history.map(\.completionKey))
    }

    var body: some View {
        TabView {
            nextWorkoutPage
            programPage
            historyPage
        }
        .task {
            connectivity.activate()
            await connectivity.pull()
            isLoadingProgress = false
        }
        .alert(
            L10n.healthApp,
            isPresented: Binding(
                get: { connectivity.errorMessage != nil },
                set: { if !$0 { connectivity.clearError() } }
            )
        ) {
            Button(L10n.gotIt) {
                connectivity.clearError()
            }
        } message: {
            Text(connectivity.errorMessage ?? "")
        }
    }

    private var nextWorkout: PlannedWorkout? {
        plan.nextWorkout(completedKeys: completedKeys)
    }

    private var nextWorkoutPage: some View {
        NavigationStack {
            VStack(spacing: 10) {
                if isLoadingProgress {
                    ProgressView()
                } else if let workout = nextWorkout {
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
                } else {
                    Text(L10n.planComplete)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle(L10n.appName)
            .toolbar {
                syncToolbarContent
            }
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
                } else if connectivity.history.isEmpty {
                    Text(L10n.noHistory)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List(connectivity.history) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
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

    @ToolbarContentBuilder
    private var syncToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                WKInterfaceDevice.current().play(.click)
                Task { await connectivity.pull() }
            } label: {
                Image(systemName: "arrow.down.circle")
            }
            .accessibilityLabel(L10n.pullFromIphone)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                WKInterfaceDevice.current().play(.click)
                Task { await connectivity.push() }
            } label: {
                Image(systemName: "arrow.up.circle")
            }
            .accessibilityLabel(L10n.pushToIphone)
        }
    }
}
