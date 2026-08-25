import SwiftUI

extension Color {
    static let brandPink = Color(red: 232 / 255, green: 40 / 255, blue: 86 / 255)
}

@main
struct Couch5KWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView(plan: .standard)
                .tint(.brandPink)
        }
    }
}
