import SwiftUI
import Charts

/// One user's one ActivityWatch bucket. This is intentionally a raw-event
/// timeline, not an attempt to claim parity with the web dashboard's AFK,
/// overlapping-watcher de-duplication and effective-focus calculations.
struct AERTEXWatchBucketEvent: Decodable {
    struct EventData: Decodable {
        let app: String?
        let title: String?
        let status: String?
        let url: String?
    }
    let timestamp: String
    let duration: Double
    let data: EventData?
}

private struct AERTEXWatchHour: Identifiable {
    let date: Date
    let seconds: Double
    var id: Date { date }
    var minutes: Double { seconds / 60 }
}

struct AERTEXWatchBucketView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @EnvironmentObject private var preferences: AppPreferences
    let bucketId: String
    let bucketName: String

    @State private var events: [AERTEXWatchBucketEvent] = []
    @State private var rangeHours = 24
    @State private var loading = false
    @State private var loaded = false
    @State private var error: String?

    private let calendar = Calendar.current

    private var lastDay: [AERTEXWatchHour] {
        let end = Date()
        let start = end.addingTimeInterval(-Double(rangeHours) * 3600)
        let firstHour = calendar.dateInterval(of: .hour, for: start)?.start ?? start
        let hours: [Date] = (0...rangeHours).compactMap {
            calendar.date(byAdding: .hour, value: $0, to: firstHour)
        }
        var seconds: [Date: Double] = [:]
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for event in events where event.duration > 0 {
            let timestamp = parser.date(from: event.timestamp) ?? ISO8601DateFormatter().date(from: event.timestamp)
            guard let begin = timestamp else { continue }
            var cursor = max(begin, start)
            let endTime = min(begin.addingTimeInterval(min(event.duration, 604800)), end)
            while cursor < endTime {
                guard let interval = calendar.dateInterval(of: .hour, for: cursor) else { break }
                let next = min(interval.end, endTime)
                guard next > cursor else { break }
                seconds[interval.start, default: 0] += next.timeIntervalSince(cursor)
                cursor = next
            }
        }
        return hours.map { AERTEXWatchHour(date: $0, seconds: seconds[$0] ?? 0) }
    }

    private var topApps: [(name: String, minutes: Double)] {
        var amounts: [String: Double] = [:]
        for event in events where event.duration > 0 {
            let app = event.data?.app?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if app.isEmpty { continue }
            amounts[app, default: 0] += min(event.duration, 604800)
        }
        return amounts.map { (name: $0.key, minutes: $0.value / 60) }
            .sorted { $0.minutes > $1.minutes }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 9) {
                    Text(bucketName).font(.headline)
                    Text(bucketId).font(.caption2).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            Section {
                Picker("统计窗口", selection: $rangeHours) {
                    Text("24 小时").tag(24)
                    Text("7 天").tag(168)
                }
                .pickerStyle(.segmented)
            }
            if loading && !loaded {
                Section { ProgressView("正在读取最近 24 小时的 ActivityWatch 事件…") }
            } else if loaded {
                Section("最近 \(rangeHours == 24 ? "24 小时" : "7 天") · 原始事件时长") {
                    Chart(lastDay) { value in
                        BarMark(
                            x: .value("时间", value.date),
                            y: .value("分钟", value.minutes)
                        )
                        .foregroundStyle(preferences.accentControlColor)
                    }
                    .frame(height: 185)
                    .chartYScale(domain: .automatic(includesZero: true))
                    Text("此图展示单一数据源的事件时长，尚未进行网站使用的 AFK/多设备去重和专注算法；多个来源不能直接相加。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("应用时长排行 · 原始事件") {
                    if topApps.isEmpty {
                        Text("没有可聚合的应用信息。").foregroundStyle(.secondary)
                    }
                    ForEach(topApps, id: \.name) { item in
                        HStack {
                            Text(item.name).lineLimit(1)
                            Spacer()
                            Text(String(format: "%.1f 分钟", item.minutes))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("只对当前数据源返回的事件求和。重叠事件、AFK 状态和超过 800 条的分页尚未完成去重，因此不作为实际专注时间。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("最近事件（\(events.count) 条）") {
                    if events.isEmpty {
                        Text("这个数据源最近 24 小时没有事件。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(events.enumerated()), id: \.offset) { indexed in
                        let event = indexed.element
                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.data?.app ?? event.data?.title ?? event.data?.status ?? "活动事件")
                                .font(.subheadline.weight(.semibold))
                            if let title = event.data?.title, title != event.data?.app {
                                Text(title).font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            HStack(spacing: 12) {
                                Text(event.timestamp)
                                    .lineLimit(1)
                                Text(String(format: "%.1f 秒", event.duration))
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Watch 活动时间线")
        .aertexGlassBackButton()
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .onChange(of: rangeHours) { _ in Task { await load() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(loading)
            }
        }
    }

    private func load() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        guard let encodedId = bucketId.addingPercentEncoding(withAllowedCharacters: allowed) else {
            error = "数据源 ID 无法编码。"
            return
        }
        let now = Date()
        let iso = ISO8601DateFormatter()
        let start = iso.string(from: now.addingTimeInterval(-Double(rangeHours) * 3600))
        let end = iso.string(from: now)
        let path = "/api/native/watch/buckets/" + encodedId + "/events?start=" + start + "&end=" + end + "&limit=800"
        do {
            events = try await auth.nativeGet(
                [AERTEXWatchBucketEvent].self, product: .watch, path: path
            )
            loaded = true
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
