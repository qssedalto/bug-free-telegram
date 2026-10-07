import SwiftUI

@main
struct AgreeQuestionApp: App {
    @StateObject private var preferences = AppPreferences()
    @StateObject private var runtime = RuntimeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(preferences)
                .environmentObject(runtime)
                .preferredColorScheme(preferences.colorScheme)
                .tint(preferences.accentColor)
                .task { runtime.checkIn(amount: DebtEngine.amount(on: Date(), preferences: preferences)) }
        }
    }
}
