import SwiftUI

struct OnboardingView: View {
    private struct IntroPage {
        let icon: String
        let title: String
        let message: String
    }

    @AppStorage("voicePromptsEnabled") private var voicePromptsEnabled = true
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.simplifiedChinese.rawValue
    @AppStorage("coachLanguage") private var coachLanguage = AppLanguage.simplifiedChinese.rawValue
    @AppStorage("remindersEnabled") private var remindersEnabled = true
    @AppStorage("unitSystem") private var unitSystem = "metric"
    @AppStorage("reminderWeekdays") private var storedWeekdays = "2,4,7"

    @State private var page = 0
    @State private var selectedWeekdays: Set<Int> = [2, 4, 7]

    let onComplete: () -> Void
    private let reminderScheduler = WorkoutReminderScheduler()

    private var pages: [IntroPage] {
        [
            IntroPage(
                icon: "figure.run.circle.fill",
                title: L10n.onboardingStartWalkingTitle,
                message: L10n.onboardingStartWalkingMessage
            ),
            IntroPage(
                icon: "calendar.badge.clock",
                title: L10n.onboardingThreeTimesTitle,
                message: L10n.onboardingThreeTimesMessage
            ),
            IntroPage(
                icon: "waveform.and.person.filled",
                title: L10n.onboardingTalkPaceTitle,
                message: L10n.onboardingTalkPaceMessage
            )
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandPink.opacity(0.16), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        introPage(page)
                            .tag(index)
                    }

                    preferencesPage
                        .tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(action: advance) {
                    Text(page == pages.count ? L10n.startNineWeekPlan : L10n.continueAction)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            selectedWeekdays = Set(
                storedWeekdays
                    .split(separator: ",")
                    .compactMap { Int($0) }
            )
            synchronizeCoachLanguage()
        }
        .onChange(of: appLanguage) { _, _ in
            synchronizeCoachLanguage()
        }
    }

    private func introPage(_ intro: IntroPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: intro.icon)
                .font(.system(size: 80))
                .foregroundStyle(Color.brandPink)
                .symbolRenderingMode(.hierarchical)

            Text(intro.title)
                .font(.largeTitle.bold())

            Text(intro.message)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .lineSpacing(6)
                .padding(.horizontal, 30)

            if page == 2 {
                safetyNotice
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding(.top, 30)
    }

    private var preferencesPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.setUpPlan)
                        .font(.largeTitle.bold())
                    Text(L10n.preferencesCanChange)
                        .foregroundStyle(.secondary)
                }

                GroupBox {
                    VStack(spacing: 0) {
                        AppLanguagePicker(language: $appLanguage)
                            .padding(.vertical, 8)

                        Divider()

                        Toggle(isOn: $voicePromptsEnabled) {
                            Label(L10n.voiceCoaching, systemImage: "speaker.wave.2.fill")
                        }
                        .padding(.vertical, 8)

                        Divider()

                        Toggle(isOn: $remindersEnabled) {
                            Label(L10n.trainingReminders, systemImage: "bell.badge.fill")
                        }
                        .padding(.vertical, 8)
                    }
                }

                if remindersEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.trainingDays)
                            .font(.headline)

                        HStack(spacing: 7) {
                            ForEach(weekdayOptions, id: \.id) { option in
                                Button {
                                    toggleWeekday(option.id)
                                } label: {
                                    Text(option.label)
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(
                                            selectedWeekdays.contains(option.id)
                                                ? Color.brandPink
                                                : Color(.secondarySystemBackground)
                                        )
                                        .foregroundStyle(
                                            selectedWeekdays.contains(option.id)
                                                ? .white
                                                : .primary
                                        )
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(L10n.weekdayAccessibility(option.id))
                                .accessibilityAddTraits(
                                    selectedWeekdays.contains(option.id) ? .isSelected : []
                                )
                            }
                        }

                        Text(L10n.recoveryDayAdvice)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.distanceUnit)
                        .font(.headline)
                    Picker(L10n.distanceUnit, selection: $unitSystem) {
                        Text(L10n.kilometers).tag("metric")
                        Text(L10n.miles).tag("imperial")
                    }
                    .pickerStyle(.segmented)
                }

                safetyNotice
            }
            .padding(24)
        }
    }

    private var safetyNotice: some View {
        Label {
            Text(L10n.safetyNotice)
        } icon: {
            Image(systemName: "heart.text.clipboard")
                .foregroundStyle(.red)
        }
        .font(.footnote)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var weekdayOptions: [(id: Int, label: String)] {
        [2, 3, 4, 5, 6, 7, 1].map { ($0, L10n.weekday($0, short: true)) }
    }

    private func toggleWeekday(_ weekday: Int) {
        if selectedWeekdays.contains(weekday) {
            guard selectedWeekdays.count > 1 else { return }
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
    }

    private func advance() {
        if page < pages.count {
            withAnimation {
                page += 1
            }
        } else {
            storedWeekdays = selectedWeekdays.sorted().map(String.init).joined(separator: ",")
            Task {
                do {
                    try await reminderScheduler.update(
                        enabled: remindersEnabled,
                        weekdays: selectedWeekdays,
                        hour: 7,
                        minute: 0
                    )
                } catch {
                    remindersEnabled = false
                }
                onComplete()
            }
        }
    }

    private func synchronizeCoachLanguage() {
        let language = AppLanguage(rawValue: appLanguage) ?? .simplifiedChinese
        if appLanguage != language.rawValue {
            appLanguage = language.rawValue
        }
        coachLanguage = language.rawValue
    }
}

struct AppLanguagePicker: View {
    @Binding var language: String

    var body: some View {
        Picker(L10n.appLanguage, selection: $language) {
            ForEach(AppLanguage.allCases) { option in
                Text(option.displayName).tag(option.rawValue)
            }
        }
        .pickerStyle(.segmented)
    }
}

#Preview {
    OnboardingView {}
}
