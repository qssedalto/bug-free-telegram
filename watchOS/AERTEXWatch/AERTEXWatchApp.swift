import SwiftUI
import WatchConnectivity

/// Standalone watchOS companion prototype. The iPhone owns AERTEX ID tokens;
/// the watch requests sanitized status over WatchConnectivity instead of
/// storing a Supabase session or an API key in watch storage.
@main
struct AERTEXWatchCompanionApp: App {
    @StateObject private var bridge = AERTEXWatchBridge()

    var body: some Scene {
        WindowGroup {
            AERTEXWatchDashboard()
                .environmentObject(bridge)
        }
    }
}

struct AERTEXWatchDashboard: View {
    @EnvironmentObject private var bridge: AERTEXWatchBridge

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    Label("AERTEX", systemImage: "applewatch")
                        .font(.headline)
                        .foregroundStyle(.tint)
                    Text("Watch 同步")
                        .font(.title3.weight(.bold))
                    if bridge.isReachable {
                        Label("iPhone 已连接", systemImage: "iphone.gen3")
                            .foregroundStyle(.green)
                    } else {
                        Label("等待 iPhone", systemImage: "iphone.slash")
                            .foregroundStyle(.secondary)
                    }
                    if let status = bridge.status {
                        LabeledContent("电脑数据源", value: String(status.bucketCount))
                        if let host = status.lastHost {
                            Text(host).font(.footnote).foregroundStyle(.secondary)
                        }
                        if let lastSync = status.lastSync {
                            Text("最近同步：\(lastSync)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("从 iPhone 获取 AERTEX Watch 的 ActivityWatch 云端状态。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let error = bridge.error {
                        Text(error).font(.footnote).foregroundStyle(.orange)
                    }
                    Button {
                        bridge.refresh()
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!bridge.isReachable || bridge.loading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("AERTEX")
        }
    }
}

struct AERTEXWatchStatusSnapshot: Equatable {
    let bucketCount: Int
    let lastHost: String?
    let lastSync: String?
}

@MainActor
final class AERTEXWatchBridge: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isReachable = false
    @Published var loading = false
    @Published var error: String?
    @Published var status: AERTEXWatchStatusSnapshot?

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func refresh() {
        guard WCSession.isSupported(), WCSession.default.isReachable else {
            error = "请先打开 iPhone 上的 AERTEX。"
            return
        }
        loading = true
        error = nil
        WCSession.default.sendMessage(
            ["type": "aertex.watch.status.v1"],
            replyHandler: { [weak self] reply in
                Task { @MainActor in
                    guard let self else { return }
                    self.loading = false
                    if let message = reply["error"] as? String {
                        self.error = message
                        return
                    }
                    self.status = AERTEXWatchStatusSnapshot(
                        bucketCount: reply["bucket_count"] as? Int ?? 0,
                        lastHost: reply["last_host"] as? String,
                        lastSync: reply["last_sync"] as? String
                    )
                }
            },
            errorHandler: { [weak self] failure in
                Task { @MainActor in
                    self?.loading = false
                    self?.error = failure.localizedDescription
                }
            }
        )
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isReachable = session.isReachable
            if isReachable { refresh() }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
            if isReachable { refresh() }
        }
    }
}
