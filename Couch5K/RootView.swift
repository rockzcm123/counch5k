import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.english.rawValue
    @AppStorage("coachLanguage") private var coachLanguage = AppLanguage.english.rawValue

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ProgramOverviewView(plan: .standard)
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .animation(.easeInOut, value: hasCompletedOnboarding)
        .environment(\.locale, selectedLanguage.locale)
        .onAppear(perform: synchronizeCoachLanguage)
        .onChange(of: appLanguage) { _, _ in
            synchronizeCoachLanguage()
        }
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguage) ?? .english
    }

    private func synchronizeCoachLanguage() {
        if appLanguage != selectedLanguage.rawValue {
            appLanguage = selectedLanguage.rawValue
        }
        if coachLanguage != selectedLanguage.rawValue {
            coachLanguage = selectedLanguage.rawValue
        }
    }
}

#Preview {
    RootView()
}
