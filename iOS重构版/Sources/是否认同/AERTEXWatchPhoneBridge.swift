import Foundation
import WatchConnectivity

/// Phone-only WatchConnectivity adapter. It never passes bearer tokens to
/// Apple Watch; only a minimal user-scoped status snapshot is returned.
final class AERTEXWatchPhoneBridge: NSObject, WCSessionDelegate {
    private weak var auth: AERTEXAuthStore?

    init(auth: AERTEXAuthStore) {
        self.auth = auth
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard message["type"] as? String == "aertex.watch.status.v1" else {
            replyHandler(["error": "不支持的手表请求"])
            return
        }
        Task { @MainActor in
            guard let auth = self.auth, auth.isAuthenticated else {
                replyHandler(["error": "请在 iPhone 登录 AERTEX ID"])
                return
            }
            do {
                let status = try await auth.nativeGet(
                    AERTEXWatchStatus.self,
                    product: .watch,
                    path: "/api/native/watch/status"
                )
                var result: [String: Any] = ["bucket_count": status.buckets.count]
                if let host = status.last_host { result["last_host"] = host }
                if let sync = status.last_sync { result["last_sync"] = sync }
                replyHandler(result)
            } catch {
                replyHandler(["error": "同步暂不可用，请在 iPhone 重试"])
            }
        }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
