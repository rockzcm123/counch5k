import SwiftData
import SwiftUI

struct CustomWorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomWorkout.createdAt, order: .reverse)
    private var workouts: [CustomWorkout]

    @State private var isCreatingWorkout = false

    let onStart: (CustomWorkout) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.noCustomWorkouts, systemImage: "slider.horizontal.3")
                    } description: {
                        Text(L10n.noCustomWorkoutsDescription)
                    } actions: {
                        Button(L10n.createWorkout) {
                            isCreatingWorkout = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(workouts) { workout in
                            workoutRow(workout)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle(L10n.customWorkouts)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreatingWorkout = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(L10n.createCustomWorkout)
                }
            }
            .sheet(isPresented: $isCreatingWorkout) {
                CustomWorkoutEditor { workout in
                    modelContext.insert(workout)
                    do {
                        try modelContext.save()
                    } catch {
                        assertionFailure("Unable to save custom workout: \(error)")
                    }
                }
            }
        }
    }

    private func workoutRow(_ workout: CustomWorkout) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.headline)
                    Text(workout.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onStart(workout)
                } label: {
                    Image(systemName: "play.fill")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .accessibilityLabel(L10n.startNamedWorkout(workout.name))
            }

            HStack {
                Label(
                    workout.trainingSession.totalDuration.workoutDurationText,
                    systemImage: "clock"
                )
                Label(L10n.repeatCount(workout.cycles), systemImage: "repeat")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Unable to delete custom workout: \(error)")
        }
    }
}

private struct CustomWorkoutEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = L10n.defaultCustomWorkoutName
    @State private var warmupSeconds = 300
    @State private var runSeconds = 60
    @State private var walkSeconds = 90
    @State private var cycles = 8
    @State private var cooldownSeconds = 300

    let onSave: (CustomWorkout) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.name) {
                    TextField(L10n.workoutName, text: $name)
                }

                Section(L10n.intervals) {
                    DurationStepper(title: L10n.running, seconds: $runSeconds, range: 30...1_800)
                    DurationStepper(title: L10n.walking, seconds: $walkSeconds, range: 30...600)
                    Stepper(L10n.repeatRounds(cycles), value: $cycles, in: 1...20)
                }

                Section(L10n.warmupAndCooldown) {
                    DurationStepper(title: L10n.warmup, seconds: $warmupSeconds, range: 60...900)
                    DurationStepper(title: L10n.cooldown, seconds: $cooldownSeconds, range: 60...900)
                }
            }
            .navigationTitle(L10n.newWorkout)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        onSave(
                            CustomWorkout(
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                warmupSeconds: warmupSeconds,
                                runSeconds: runSeconds,
                                walkSeconds: walkSeconds,
                                cycles: cycles,
                                cooldownSeconds: cooldownSeconds
                            )
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct DurationStepper: View {
    let title: String
    @Binding var seconds: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $seconds, in: range, step: 30) {
            LabeledContent(title, value: durationText)
        }
    }

    private var durationText: String {
        L10n.duration(seconds)
    }
}
