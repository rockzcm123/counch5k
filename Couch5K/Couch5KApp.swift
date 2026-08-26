import SwiftUI
import SwiftData

extension Color {
    static let brandPink = Color(red: 232 / 255, green: 40 / 255, blue: 86 / 255)
    static let brandBlack = Color(red: 29 / 255, green: 29 / 255, blue: 29 / 255)
    static let brandGray = Color(red: 46 / 255, green: 46 / 255, blue: 46 / 255)
    static let brandWhite = Color(red: 244 / 255, green: 245 / 255, blue: 245 / 255)
}

@main
struct Couch5KApp: App {
    @AppStorage(AppTheme.storageKey) private var colorTheme = AppTheme.pink.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(AppTheme(rawValue: colorTheme)?.color ?? .brandPink)
        }
        .modelContainer(for: [WorkoutRecord.self, CustomWorkout.self])
    }
}
