import SwiftUI
import WatchConnectivity

/// Companion of AERTEX for iPhone. Authenticated API calls are performed
/// on the phone; the watch only gets sanitized ActivityWatch cloud status.
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
                VStack(alignment: .leading, spacing: 12) {
                    Label("AERTEX", systemImage: "applewatch")
                        .font(.headline)
                        .foregroundStyle(.tint)

                    Label(
                        bridge.isReachable ? "iPhone 已连接" : "iPhone 暂不可连接",
                        systemImage: bridge.isReachable ? "iphone.gen3" : "iphone.slash"
                    )
                    .font(.caption)
                    .foregroundStyle(bridge.isReachable ? .green : .secondary)

                    if let snapshot = bridge.status {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("电脑 ActivityWatch 数据源")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(snapshot.bucketCount.formatted())
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .contentTransition(.numericText())
                                .accessibilityLabel("已同步的数据源：\(snapshot.bucketCount) 个")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(11)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

                        if let host = snapshot.lastHost, !host.isEmpty {
                            Label(host, systemImage: "desktopcomputer")
                                .font(.footnote)
                                .lineLimit(2)
                        }
                        if let sync = snapshot.lastSync, !sync.isEmpty {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("最近同步时间")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(sync)
                                    .font(.footnote)
                            }
                        }
                        if let updated = bridge.lastUpdated {
                            Text("状态获取：\(updated.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if bridge.fromBackground {
                            Label("上次缓存 · 可能不是实时数据", systemImage: "clock.arrow.circlepath")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("登录 iPhone 上的 AERTEX 后，可查看电脑 ActivityWatch 的云端同步状态。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let error = bridge.error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        bridge.refresh()
                    } label: {
                        if bridge.loading {
                            HStack {
                                ProgressView()
                                Text("正在刷新…")
                            }
                        } else {
                            Label("从 iPhone 刷新", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!bridge.isReachable || bridge.loading)

                    Text("这里只显示电脑活动数据，不读取 Apple 健康或运动圆环。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            }
            .navigationTitle("AERTEX Watch")
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
    @Published var lastUpdated: Date?
    @Published var fromBackground = false

    override init() {
        super.init()
        guard WCSession.isSupported() else {
            error = "当前设备不支持与 iPhone 通信"
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func refresh() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable else {
            error = "请打开配对 iPhone 上的 AERTEX 后重试。"
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
                    self.applySnapshot(reply, fromBackground: false)
                }
            },
            errorHandler: { [weak self] failure in
                Task { @MainActor in
                    self?.loading = false
                    self?.error = "通信失败：\(failure.localizedDescription)"
                }
            }
        )
    }

    private func applySnapshot(_ payload: [String: Any], fromBackground: Bool) {
        if payload["type"] as? String == "aertex.watch.signedout.v1" {
            status = nil
            lastUpdated = nil
            error = "请在 iPhone 登录 AERTEX ID"
            return
        }
        guard payload["type"] as? String == "aertex.watch.snapshot.v1",
              let count = payload["bucket_count"] as? Int, count >= 0 else {
            error = "收到的同步数据格式不正确"
            return
        }
        status = AERTEXWatchStatusSnapshot(
            bucketCount: count,
            lastHost: payload["last_host"] as? String,
            lastSync: payload["last_sync"] as? String
        )
        if let timestamp = payload["fetched_at"] as? Double {
            lastUpdated = Date(timeIntervalSince1970: timestamp)
        } else {
            lastUpdated = Date()
        }
        self.fromBackground = fromBackground
        error = nil
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isReachable = session.isReachable
            if activationState == .activated {
                let context = session.receivedApplicationContext
                if !context.isEmpty {
                    applySnapshot(context, fromBackground: true)
                }
                if isReachable { refresh() }
            } else if let error {
                self.error = error.localizedDescription
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
            if isReachable { refresh() }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            applySnapshot(applicationContext, fromBackground: true)
        }
    }
}
