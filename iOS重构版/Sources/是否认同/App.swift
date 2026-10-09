import SwiftUI
import UIKit

@main
struct AERTEXApp: App {
    @StateObject private var auth = AERTEXAuthStore()
    @StateObject private var preferences = AppPreferences()
    @StateObject private var runtime = RuntimeStore()
    @State private var watchBridge: AERTEXWatchPhoneBridge?

    var body: some Scene {
        WindowGroup {
            Group {
                switch auth.state {
                case .restoring:
                    ZStack {
                        LiquidGlassBackdrop(accent: preferences.accentColor, intense: true)
                        ProgressView("正在验证 AERTEX 会话…")
                            .font(.headline)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 16)
                            .liquidGlassCapsule(tint: preferences.accentColor.opacity(0.08))
                    }

                case .signedOut:
                    AERTEXLoginView()

                case .signedIn:
                    AERTEXRootView()
                        .task {
                            // Preserve the module's local streak/snapshot data when launching AERTEX.
                            runtime.checkIn(amount: DebtEngine.amount(on: Date(), preferences: preferences))
                        }
                }
            }
            .environmentObject(auth)
            .environmentObject(preferences)
            .environmentObject(runtime)
            .tint(preferences.accentControlColor)
            .task {
                if watchBridge == nil {
                    watchBridge = AERTEXWatchPhoneBridge(auth: auth)
                }
                if auth.state == .restoring {
                    await auth.restore()
                }
            }
            // Publish only a sanitized Watch status. Session credentials
            // remain on the iPhone, including when the account changes.
            .task(id: auth.state) {
                if auth.isAuthenticated {
                    await watchBridge?.publishStatus()
                } else {
                    watchBridge?.clearStatus()
                }
            }
            .task(id: auth.user?.accentId) {
                preferences.applyAERTEXAccent(auth.user?.accentId)
            }
        }
    }
}
