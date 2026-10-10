import SwiftUI

// MARK: - First-party native AERTEX API DTOs
// Product screens use SwiftUI; only mathematical rich-text canvas uses sandboxed WKWebView,
// reuse web cookies or persist access tokens in view state.

struct AERTEXStudioOverview: Decodable {
    struct Counts: Decodable {
        let active_projects: Int
        let open_tasks: Int
        let drafts: Int
        let notes: Int
    }

    struct Project: Decodable, Identifiable {
        let id: String
        let name: String
        let summary: String?
        let status: String?
    }

    struct Task: Decodable, Identifiable {
        let id: String
        let title: String
        let project_name: String?
        let priority: String?
        let due_at: String?
    }

    let counts: Counts
    let projects: [Project]
    let tasks: [Task]
    let generated_at: String?
}

struct AERTEXConversation: Decodable, Identifiable {
    let id: String
    let title: String?
    let model: String?
    let updated_at: String?
    let is_pinned: Bool?

    var displayTitle: String {
        guard let title, !title.isEmpty else { return "未命名会话" }
        return title
    }
}

struct AERTEXConversationDetail: Decodable {
    struct Message: Decodable, Identifiable {
        let id: String
        let role: String
        let content: String?
        let created_at: String?
    }

    let conversation: AERTEXConversation
    let messages: [Message]
}

struct AERTEXWatchStatus: Decodable {
    struct Bucket: Decodable {
        let id: String?
        let hostname: String?
        let type: String?
        let last_sync: String?
    }

    let last_sync: String?
    let last_host: String?
    let buckets: [String: Bucket]
}

// MARK: - Shared native-only feedback

struct AERTEXNativeLoadMessage: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("暂时无法加载")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重新连接", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}

// MARK: - AERTEX Studio dashboard

struct AERTEXStudioNativeView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @State private var overview: AERTEXStudioOverview?
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        Group {
            if let overview {
                List {
                    Section("我的工作台") {
                        LabeledContent("活跃项目", value: String(overview.counts.active_projects))
                        LabeledContent("待办任务", value: String(overview.counts.open_tasks))
                        LabeledContent("草稿", value: String(overview.counts.drafts))
                        LabeledContent("笔记", value: String(overview.counts.notes))
                    }
                    Section {
                        NavigationLink {
                            AERTEXStudioManagerView()
                        } label: {
                            Label("管理项目与任务", systemImage: "square.and.pencil")
                                .font(.headline)
                        }
                    }

                    Section("正在进行的项目") {
                        if overview.projects.isEmpty {
                            Text("目前没有活跃项目").foregroundStyle(.secondary)
                        }
                        ForEach(overview.projects) { project in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(project.name).font(.headline)
                                if let summary = project.summary, !summary.isEmpty {
                                    Text(summary).font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 3)
                        }
                    }
                    Section("待办任务") {
                        if overview.tasks.isEmpty {
                            Text("目前没有待办任务").foregroundStyle(.secondary)
                        }
                        ForEach(overview.tasks) { task in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(task.title).font(.subheadline.weight(.medium))
                                if let project = task.project_name, !project.isEmpty {
                                    Text(project).font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 3)
                        }
                    }
                    Section {
                        Label("项目与任务可以进入管理页进行真实云端编辑，统计来自个人工作台。", systemImage: "lock.shield")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .refreshable { await load() }
            } else if loading {
                ProgressView("正在同步 Studio…")
            } else {
                AERTEXNativeLoadMessage(message: error ?? "尚未加载工作台") {
                    Task { await load() }
                }
            }
        }
        .navigationTitle("Studio")
        .aertexGlassBackButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(loading)
                .accessibilityLabel("刷新工作台")
            }
        }
        .task { if overview == nil { await load() } }
    }

    private func load() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            overview = try await auth.nativeGet(
                AERTEXStudioOverview.self, product: .studio, path: "/api/native/studio/overview"
            )
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - AERTEX Intelligence conversation history

// Native Intelligence chat UI now lives in AERTEXIntelligenceChat.swift.

struct AERTEXWatchNativeView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @State private var status: AERTEXWatchStatus?
    @State private var error: String?
    @State private var loading = false

    private struct WatchSource: Identifiable {
        let id: String
        let bucket: AERTEXWatchStatus.Bucket
    }

    private var sources: [WatchSource] {
        (status?.buckets ?? [:])
            .map { WatchSource(id: $0.key, bucket: $0.value) }
            .sorted { $0.id < $1.id }
    }

    var body: some View {
        Group {
            if let status {
                List {
                    Section("同步概览") {
                        LabeledContent("数据源数量", value: String(status.buckets.count))
                        LabeledContent("最近同步", value: status.last_sync ?? "尚未同步")
                        LabeledContent("来源设备", value: status.last_host ?? "暂无")
                    }
                    Section("活动数据源") {
                        if sources.isEmpty {
                            Text("尚无 ActivityWatch 数据源").foregroundStyle(.secondary)
                        }
                        ForEach(sources) { source in
                            NavigationLink {
                                AERTEXWatchBucketView(
                                    bucketId: source.id,
                                    bucketName: source.bucket.hostname ?? source.id
                                )
                            } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(source.bucket.hostname ?? "未知设备").font(.headline)
                                Text(source.bucket.type ?? source.id)
                                    .font(.caption).foregroundStyle(.secondary)
                                if let date = source.bucket.last_sync {
                                    Text("最近同步：\(date)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 3)
                            }
                        }
                    }
                    Section {
                        Label { AERTEXBrandedText("这里展示已同步至 AERTEX Watch 云端的电脑活动数据源，不会自动读取 iPhone 或 Apple Watch 健康数据。") } icon: { Image(systemName: "lock.shield") }
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .refreshable { await load() }
            } else if loading {
                ProgressView("正在读取 Watch 云端状态…")
            } else {
                AERTEXNativeLoadMessage(message: error ?? "尚未获取活动数据") {
                    Task { await load() }
                }
            }
        }
        .navigationTitle("Watch")
        .aertexGlassBackButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(loading)
                    .accessibilityLabel("刷新 Watch")
            }
        }
        .task { if status == nil { await load() } }
    }

    private func load() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            status = try await auth.nativeGet(
                AERTEXWatchStatus.self, product: .watch, path: "/api/native/watch/status"
            )
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
