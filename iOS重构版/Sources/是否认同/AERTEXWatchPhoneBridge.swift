import Foundation
import WatchConnectivity

/// Only the iPhone holds AERTEX ID session credentials. The Watch sees
/// non-sensitive ActivityWatch status, never bearer or refresh tokens.
@MainActor
final class AERTEXWatchPhoneBridge: NSObject, WCSessionDelegate {
    private weak var auth: AERTEXAuthStore?
    private let requestType = "aertex.watch.status.v1"
    private let snapshotType = "aertex.watch.snapshot.v1"

    init(auth: AERTEXAuthStore) {
        self.auth = auth
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    private func statusSnapshot() async throws -> [String: Any] {
        guard let auth, auth.isAuthenticated else {
            throw AERTEXWatchBridgeError.notSignedIn
        }
        let status = try await auth.nativeGet(
            AERTEXWatchStatus.self,
            product: .watch,
            path: "/api/native/watch/status"
        )
        var payload: [String: Any] = [
            "type": snapshotType,
            "bucket_count": status.buckets.count,
            "fetched_at": Date().timeIntervalSince1970
        ]
        if let host = status.last_host { payload["last_host"] = host }
        if let lastSync = status.last_sync { payload["last_sync"] = lastSync }
        return payload
    }

    /// Pushes the latest snapshot even when the Watch app is not foregrounded.
    /// WCSession coalesces applicationContext updates; this isn't streaming.
    func publishStatus() async {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        do {
            try WCSession.default.updateApplicationContext(try await statusSnapshot())
        } catch {
            // The interactive request still returns a meaningful error below.
        }
    }

    func clearStatus() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext(["type": "aertex.watch.signedout.v1"])
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard message["type"] as? String == "aertex.watch.status.v1" else {
            replyHandler(["error": "不支持的手表请求"])
            return
        }
        Task { @MainActor in
            do {
                let payload = try await self.statusSnapshot()
                if WCSession.default.activationState == .activated {
                    try? WCSession.default.updateApplicationContext(payload)
                }
                replyHandler(payload)
            } catch AERTEXWatchBridgeError.notSignedIn {
                replyHandler(["error": "请先在 iPhone 登录 AERTEX ID"])
            } catch {
                replyHandler(["error": "同步暂不可用，请在 iPhone 上重试"])
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in await self.publishStatus() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}

private enum AERTEXWatchBridgeError: Error {
    case notSignedIn
}
