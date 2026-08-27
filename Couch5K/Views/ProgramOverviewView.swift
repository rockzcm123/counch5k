import SwiftData
import SwiftUI
import UIKit

struct ProgramOverviewView: View {
    let plan: TrainingPlan

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.completedAt, order: .reverse)
    private var records: [WorkoutRecord]

    @StateObject private var activeStore = ActiveWorkoutStore()
    @State private var expandedWeeks: Set<Int> = [1]
    @State private var selectedWeekNumber: Int?
    @State private var isShowingSettings = false
    @State private var selectedWorkout: SelectedWorkout?
    @State private var healthMessage: String?
    @AppStorage(AppTheme.storageKey) private var colorTheme = AppTheme.pink.rawValue
    @AppStorage("profileName") private var profileName = ""
    @AppStorage("profilePhotoData") private var profilePhotoData = Data()

    private let healthService = HealthKitService()

    private var themeColor: Color {
        AppTheme(rawValue: colorTheme)?.color ?? .brandPink
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: L10n.greetingMorning
        case 12..<18: L10n.greetingAfternoon
        default: L10n.greetingEvening
        }
    }

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
        .tint(themeColor)
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
                VStack(spacing: 0) {
                    heroSection

                    VStack(spacing: 16) {
                        statsRow
                        dailyMotivationCard
                        weekStrip
                        selectedWeekSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingSettings) {
                PreferencesView()
            }
            .task {
                try? await healthService.requestAuthorization()
            }
        }
    }

    private var heroSection: some View {
        let workout = activeWorkout ?? nextWorkout ?? plan.orderedWorkouts.last
        let isResuming = activeWorkout != nil

        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                heroAvatar

                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.75))

                    Text(
                        profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? plan.title
                            : L10n.personalGreeting(profileName)
                    )
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.18), in: Circle())
                }
                .accessibilityLabel(L10n.settings)
            }

            if let workout {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isResuming ? L10n.unfinishedWorkout : nextWorkout == nil ? L10n.planComplete : L10n.nextWorkout)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))

                    Text(workout.displayTitle)
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("\(workout.session.totalDuration.workoutDurationText) · \(workout.session.summary)")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }

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
                    .imageScale(.large)
                    .font(.title3.bold())
                    .foregroundStyle(themeColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                }
                .background(Color.white, in: Capsule())
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                .padding(.top, 2)

                if isResuming {
                    Button(L10n.discardWorkout, role: .destructive) {
                        activeStore.clear()
                    }
                    .foregroundStyle(.white)
                    .font(.footnote.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .accessibilityHint(L10n.discardWorkoutHint)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeColor)
    }

    private var heroAvatar: some View {
        Group {
            if let uiImage = UIImage(data: profilePhotoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.2))
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(value: "\(completedKeys.count)/\(plan.sessionCount)", label: L10n.completions)
            statTile(value: "\(currentWeekNumber)/\(plan.weeks.count)", label: L10n.week)
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var currentWeekNumber: Int {
        lastRunWeekNumber ?? 1
    }

    /// The week of the most recently completed plan session, so the week
    /// strip always opens on wherever you last ran rather than jumping
    /// ahead to what's next.
    private var lastRunWeekNumber: Int? {
        records
            .filter { record in plan.weeks.contains { $0.number == record.weekNumber } }
            .max { $0.completedAt < $1.completedAt }?
            .weekNumber
    }

    private var effectiveSelectedWeek: Int {
        selectedWeekNumber ?? currentWeekNumber
    }

    private var dailyMotivationCard: some View {
        let prompt = L10n.dailyHabitPrompt(for: .now)

        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: "quote.opening")
                .font(.title2)
                .foregroundStyle(themeColor)
                .frame(width: 44, height: 44)
                .background(themeColor.opacity(0.11), in: Circle())

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(L10n.dailyHabitTip)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(prompt.principle)
                        .font(.caption2.bold())
                        .foregroundStyle(themeColor)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(themeColor.opacity(0.1), in: Capsule())
                }

                Text(prompt.message)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
        }
        .padding(18)
        .cardBackground()
        .accessibilityElement(children: .combine)
    }

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.trainingWeeks)
                    .font(.headline)

                Spacer()

                NavigationLink {
                    fullPlanView
                } label: {
                    Text(L10n.viewFullPlan)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeColor)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(plan.weeks) { week in
                        weekChip(week)
                    }
                }
            }
        }
    }

    private func weekChip(_ week: TrainingWeek) -> some View {
        let isSelected = week.number == effectiveSelectedWeek
        let isComplete = weekIsComplete(week)

        return Button {
            withAnimation(.snappy) {
                selectedWeekNumber = week.number
            }
        } label: {
            Text("\(week.number)")
                .font(.subheadline.bold())
                .frame(width: 40, height: 40)
                .foregroundStyle(isComplete || isSelected ? .white : .primary)
                .background(
                    isComplete ? Color.green : (isSelected ? themeColor : Color(.secondarySystemGroupedBackground)),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.weekTitle(week.number))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedWeekSection: some View {
        let week = plan.weeks.first { $0.number == effectiveSelectedWeek }

        return VStack(spacing: 0) {
            if let week {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.weekTitle(week.number))
                        .font(.headline)
                    Text(week.focus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)

                Divider()
                    .padding(.leading, 16)

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
                .padding(.bottom, 8)
            }
        }
        .cardBackground()
    }

    private var fullPlanView: some View {
        ScrollView {
            weekListSection
                .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.nineWeekPlan)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var weekListSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(plan.weeks.enumerated()), id: \.element.id) { index, week in
                weekRow(week)

                if expandedWeeks.contains(week.number) {
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
                    .padding(.bottom, 8)
                }

                if index != plan.weeks.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .cardBackground()
    }

    private func weekRow(_ week: TrainingWeek) -> some View {
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
                    .background(weekIsComplete(week) ? Color.green : themeColor, in: Circle())

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
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(session.totalDuration.workoutDurationText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Image(systemName: isComplete ? "arrow.clockwise.circle.fill" : "play.circle.fill")
                .foregroundStyle(themeColor)
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
    @AppStorage(AppTheme.storageKey) private var colorTheme = AppTheme.pink.rawValue

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

                Section(L10n.appearance) {
                    ThemeColorPicker(colorTheme: $colorTheme)
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

private struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
            }
    }
}

private extension View {
    func cardBackground(cornerRadius: CGFloat = 20) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius))
    }
}
