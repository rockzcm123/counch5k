import SwiftData
import SwiftUI

struct ProgramOverviewView: View {
    let plan: TrainingPlan

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.completedAt, order: .reverse)
    private var records: [WorkoutRecord]

    @StateObject private var activeStore = ActiveWorkoutStore()
    @State private var expandedWeeks: Set<Int> = [1]
    @State private var isShowingSettings = false
    @State private var selectedWorkout: SelectedWorkout?
    @State private var healthMessage: String?

    private let healthService = HealthKitService()

    private struct SelectedWorkout: Identifiable {
        let workout: PlannedWorkout
        let snapshot: ActiveWorkoutSnapshot?
        var id: String { workout.id }
    }

    var body: some View {
        TabView {
            planView
                .tabItem {
                    Label(L10n.planTab, systemImage: "figure.run")
                }

            HistoryView(records: records)
                .tabItem {
                    Label(L10n.historyTab, systemImage: "clock.arrow.circlepath")
                }

            CustomWorkoutsView { customWorkout in
                selectedWorkout = SelectedWorkout(
                    workout: PlannedWorkout(
                        weekNumber: 0,
                        session: customWorkout.trainingSession,
                        customName: customWorkout.name,
                        customIdentifier: customWorkout.workoutIdentifier
                    ),
                    snapshot: nil
                )
            }
            .tabItem {
                Label(L10n.customTab, systemImage: "slider.horizontal.3")
            }
        }
        .tint(.brandPink)
        .fullScreenCover(item: $selectedWorkout) { selection in
            WorkoutPlayerView(
                weekNumber: selection.workout.weekNumber,
                session: selection.workout.session,
                snapshot: selection.snapshot,
                activeStore: activeStore,
                workoutIdentifier: selection.workout.customIdentifier,
                workoutName: selection.workout.customName
            ) { result in
                saveCompletion(
                    selection.workout,
                    result: result
                )
            }
        }
        .alert(
            L10n.healthApp,
            isPresented: Binding(
                get: { healthMessage != nil },
                set: { if !$0 { healthMessage = nil } }
            )
        ) {
            Button(L10n.gotIt) {
                healthMessage = nil
            }
        } message: {
            Text(healthMessage ?? "")
        }
    }

    private var planView: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    dailyMotivationCard
                    heroCard
                    progressCard

                    ForEach(plan.weeks) { week in
                        weekCard(week)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(plan.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(L10n.settings)
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                PreferencesView()
            }
        }
    }

    private var dailyMotivationCard: some View {
        let prompt = L10n.dailyHabitPrompt(for: .now)

        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: "quote.opening")
                .font(.title2)
                .foregroundStyle(Color.brandPink)
                .frame(width: 44, height: 44)
                .background(Color.brandPink.opacity(0.11), in: Circle())

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(L10n.dailyHabitTip)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(prompt.principle)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.brandPink)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.brandPink.opacity(0.1), in: Capsule())
                }

                Text(prompt.message)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
        }
        .padding(18)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.brandPink.opacity(0.13))
        }
        .accessibilityElement(children: .combine)
    }

    private var heroCard: some View {
        let workout = activeWorkout ?? nextWorkout ?? plan.orderedWorkouts.last
        let isResuming = activeWorkout != nil

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(isResuming ? L10n.unfinishedWorkout : nextWorkout == nil ? L10n.planComplete : L10n.nextWorkout)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let workout {
                        Text(workout.displayTitle)
                            .font(.title2.bold())
                    }
                }

                Spacer()

                Image(systemName: nextWorkout == nil && !isResuming ? "trophy.circle.fill" : "figure.run.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.brandPink)
            }

            if let workout {
                Text(workout.session.summary)
                    .foregroundStyle(.secondary)

                HStack {
                    Label(workout.session.totalDuration.workoutDurationText, systemImage: "clock")
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Label(isResuming ? L10n.resumeProgress : L10n.easyPace, systemImage: "gauge.with.dots.needle.33percent")
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                .font(.footnote.weight(.medium))

                Button {
                    selectedWorkout = SelectedWorkout(
                        workout: workout,
                        snapshot: isResuming ? activeStore.snapshot : nil
                    )
                } label: {
                    Label(
                        isResuming ? L10n.resumeWorkout : nextWorkout == nil ? L10n.repeatWorkout : L10n.startWorkout,
                        systemImage: isResuming ? "arrow.clockwise" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)

                if isResuming {
                    Button(L10n.discardWorkout, role: .destructive) {
                        activeStore.clear()
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityHint(L10n.discardWorkoutHint)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.brandPink.opacity(0.14), Color(.secondarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22)
        )
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.planProgress)
                    .font(.headline)
                Spacer()
                Text("\(completedKeys.count) / \(plan.sessionCount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(completedKeys.count), total: Double(plan.sessionCount))
                .tint(.brandPink)

            Text(completedKeys.count == plan.sessionCount ? L10n.allPlanComplete : L10n.planProgressMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func weekCard(_ week: TrainingWeek) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy) {
                    if expandedWeeks.contains(week.number) {
                        expandedWeeks.remove(week.number)
                    } else {
                        expandedWeeks.insert(week.number)
                    }
                }
            } label: {
                HStack(spacing: 14) {
                    Text("\(week.number)")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                        .foregroundStyle(.white)
                        .background(weekIsComplete(week) ? Color.green : Color.brandPink, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.weekTitle(week.number))
                            .font(.headline)
                        Text(week.focus)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if weekIsComplete(week) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }

                    Image(systemName: expandedWeeks.contains(week.number) ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(16)

            if expandedWeeks.contains(week.number) {
                Divider()
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    ForEach(week.sessions) { session in
                        Button {
                            selectedWorkout = SelectedWorkout(
                                workout: PlannedWorkout(weekNumber: week.number, session: session),
                                snapshot: nil
                            )
                        } label: {
                            sessionRow(session, weekNumber: week.number)
                        }
                        .buttonStyle(.plain)

                        if session.id != week.sessions.last?.id {
                            Divider()
                                .padding(.leading, 54)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func sessionRow(_ session: TrainingSession, weekNumber: Int) -> some View {
        let isComplete = completedKeys.contains("\(weekNumber)-\(session.day)")

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isComplete ? Color.green : Color.secondary.opacity(0.5))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.subheadline.weight(.semibold))
                Text(session.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(session.totalDuration.workoutDurationText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Image(systemName: isComplete ? "arrow.clockwise.circle.fill" : "play.circle.fill")
                .foregroundStyle(Color.brandPink)
        }
        .padding(.vertical, 13)
    }

    private var completedKeys: Set<String> {
        Set(records.map(\.completionKey))
    }

    private var nextWorkout: PlannedWorkout? {
        plan.nextWorkout(completedKeys: completedKeys)
    }

    private var activeWorkout: PlannedWorkout? {
        guard let snapshot = activeStore.snapshot else { return nil }
        if let identifier = snapshot.workoutIdentifier,
           let name = snapshot.workoutName,
           let session = snapshot.customSession {
            return PlannedWorkout(
                weekNumber: 0,
                session: session,
                customName: name,
                customIdentifier: identifier
            )
        }
        return plan.workout(
            weekNumber: snapshot.weekNumber,
            sessionDay: snapshot.sessionDay
        )
    }

    private func weekIsComplete(_ week: TrainingWeek) -> Bool {
        week.sessions.allSatisfy {
            completedKeys.contains("\(week.number)-\($0.day)")
        }
    }

    private func saveCompletion(
        _ workout: PlannedWorkout,
        result: WorkoutResult
    ) {
        let record = WorkoutRecord(
            weekNumber: workout.weekNumber,
            sessionDay: workout.session.day,
            sessionSummary: workout.session.summary,
            plannedDuration: workout.session.totalDuration,
            startedAt: result.startedAt,
            completedAt: result.completedAt,
            distanceMeters: result.distanceMeters,
            route: result.route,
            workoutIdentifier: workout.customIdentifier ?? "",
            displayTitle: workout.customName ?? ""
        )
        modelContext.insert(record)
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Unable to save workout record: \(error)")
        }

        Task {
            do {
                try await healthService.requestAuthorization()
                try await healthService.saveWorkout(result)
            } catch {
                await MainActor.run {
                    healthMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.simplifiedChinese.rawValue
    @AppStorage("voicePromptsEnabled") private var voicePromptsEnabled = true
    @AppStorage("coachLanguage") private var coachLanguage = AppLanguage.simplifiedChinese.rawValue
    @AppStorage("remindersEnabled") private var remindersEnabled = true
    @AppStorage("unitSystem") private var unitSystem = "metric"
    @AppStorage("reminderWeekdays") private var storedWeekdays = "2,4,7"
    @AppStorage("reminderHour") private var reminderHour = 7
    @AppStorage("reminderMinute") private var reminderMinute = 0

    @State private var selectedWeekdays: Set<Int> = []
    @State private var reminderTime = Date.now
    @State private var reminderError: String?

    private let reminderScheduler = WorkoutReminderScheduler()

    private var weekdays: [(id: Int, label: String)] {
        [2, 3, 4, 5, 6, 7, 1].map { ($0, L10n.weekday($0)) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.profile) {
                    NavigationLink(L10n.aboutMe) {
                        AboutMeView()
                    }
                }

                Section(L10n.appLanguage) {
                    AppLanguagePicker(language: $appLanguage)
                }

                Section(L10n.trainingPrompts) {
                    Toggle(L10n.voiceCoaching, isOn: $voicePromptsEnabled)
                    Toggle(L10n.trainingReminders, isOn: $remindersEnabled)
                }

                if remindersEnabled {
                    Section {
                        ForEach(weekdays, id: \.id) { weekday in
                            Button {
                                toggleWeekday(weekday.id)
                            } label: {
                                HStack {
                                    Text(weekday.label)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedWeekdays.contains(weekday.id) {
                                        Image(systemName: "checkmark")
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(L10n.trainingDays)
                    } footer: {
                        Text(L10n.recoveryDayAdvice)
                    }

                    Section(L10n.reminderTime) {
                        DatePicker(
                            L10n.time,
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                Section(L10n.distanceUnit) {
                    Picker(L10n.distanceUnit, selection: $unitSystem) {
                        Text(L10n.kilometers).tag("metric")
                        Text(L10n.miles).tag("imperial")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Text(L10n.safetyNotice)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L10n.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        saveAndDismiss()
                    }
                }
            }
            .onAppear {
                selectedWeekdays = Set(
                    storedWeekdays.split(separator: ",").compactMap { Int($0) }
                )
                reminderTime = Calendar.current.date(
                    bySettingHour: reminderHour,
                    minute: reminderMinute,
                    second: 0,
                    of: .now
                ) ?? .now
                synchronizeCoachLanguage()
            }
            .onChange(of: appLanguage) { _, _ in
                synchronizeCoachLanguage()
                rescheduleRemindersForLanguageChange()
            }
            .onDisappear(perform: persistSettings)
            .alert(
                L10n.reminderSetupFailed,
                isPresented: Binding(
                    get: { reminderError != nil },
                    set: { if !$0 { reminderError = nil } }
                )
            ) {
                Button(L10n.gotIt) {
                    reminderError = nil
                }
            } message: {
                Text(reminderError ?? "")
            }
        }
    }

    private func toggleWeekday(_ weekday: Int) {
        if selectedWeekdays.contains(weekday) {
            guard selectedWeekdays.count > 1 else { return }
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
    }

    private func persistSettings() {
        storedWeekdays = selectedWeekdays.sorted().map(String.init).joined(separator: ",")
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        reminderHour = components.hour ?? 7
        reminderMinute = components.minute ?? 0
    }

    private func synchronizeCoachLanguage() {
        let language = AppLanguage(rawValue: appLanguage) ?? .simplifiedChinese
        if appLanguage != language.rawValue {
            appLanguage = language.rawValue
        }
        coachLanguage = language.rawValue
    }

    private func rescheduleRemindersForLanguageChange() {
        persistSettings()
        Task {
            do {
                try await reminderScheduler.update(
                    enabled: remindersEnabled,
                    weekdays: selectedWeekdays,
                    hour: reminderHour,
                    minute: reminderMinute
                )
            } catch {
                reminderError = error.localizedDescription
            }
        }
    }

    private func saveAndDismiss() {
        persistSettings()
        Task {
            do {
                try await reminderScheduler.update(
                    enabled: remindersEnabled,
                    weekdays: selectedWeekdays,
                    hour: reminderHour,
                    minute: reminderMinute
                )
                dismiss()
            } catch {
                reminderError = error.localizedDescription
            }
        }
    }
}

#Preview {
    ProgramOverviewView(plan: .standard)
        .modelContainer(for: [WorkoutRecord.self, CustomWorkout.self], inMemory: true)
}
