import SwiftUI

@main
struct AgreeQuestionApp: App {
    @StateObject private var auth = AERTEXAuthStore()
    @StateObject private var preferences = AppPreferences()
    @StateObject private var runtime = RuntimeStore()

    var body: some Scene {
        WindowGroup {
            Group {
                switch auth.state {
                case .restoring:
                    ProgressView("正在验证 AERTEX 会话…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())

                case .signedOut:
                    AERTEXLoginView()
                        .environmentObject(auth)
                        .environmentObject(preferences)

                case .signedIn:
                    ContentView()
                        .environmentObject(preferences)
                        .environmentObject(runtime)
                        .environmentObject(auth)
                        .task {
                            runtime.checkIn(amount: DebtEngine.amount(on: Date(), preferences: preferences))
                        }
                }
            }
            .preferredColorScheme(preferences.colorScheme)
            .tint(preferences.accentColor)
            .task {
                if auth.state == .restoring {
                    await auth.restore()
                }
            }
        }
    }
}
