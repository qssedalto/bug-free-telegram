import SwiftUI

struct AERTEXStudioProjectList: Decodable {
    struct Project: Decodable, Identifiable {
        let id: String
        let name: String
        let summary: String?
        let status: String
        let priority: String?
    }
    let projects: [Project]
    let count: Int
}

struct AERTEXStudioTaskList: Decodable {
    struct Task: Decodable, Identifiable {
        let id: String
        let title: String
        let description: String?
        let status: String
        let priority: String?
        let project_id: String?
        let due_at: String?
    }
    let tasks: [Task]
    let count: Int
}

private struct AERTEXStudioMutationResult: Decodable {
    let created: Bool?
    let saved: Bool?
    let deleted: Bool?
}

struct AERTEXStudioManagerView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @EnvironmentObject private var preferences: AppPreferences
    @State private var projects: [AERTEXStudioProjectList.Project] = []
    @State private var tasks: [AERTEXStudioTaskList.Task] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var error: String?
    @State private var showProjectForm = false
    @State private var showTaskForm = false
    @State private var projectName = ""
    @State private var projectSummary = ""
    @State private var taskTitle = ""
    @State private var selectedProjectId = ""

    var body: some View {
        List {
            Section {
                AERTEXBrandedText("项目和任务直接保存在 AERTEX Studio 的云端工作台。此处所有操作均作用于当前登录账户。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button {
                    projectName = ""
                    projectSummary = ""
                    showProjectForm = true
                } label: {
                    Label("创建项目", systemImage: "folder.badge.plus")
                        .foregroundStyle(preferences.accentControlColor)
                }
                ForEach(projects) { project in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name).font(.headline)
                        if let summary = project.summary, !summary.isEmpty {
                            Text(summary).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(project.status)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                if projects.isEmpty && !isLoading {
                    Text("尚未创建项目").foregroundStyle(.secondary)
                }
            } header: {
                Text("我的项目")
            }
            Section {
                Button {
                    taskTitle = ""
                    selectedProjectId = ""
                    showTaskForm = true
                } label: {
                    Label("新建任务", systemImage: "plus.circle.fill")
                        .foregroundStyle(preferences.accentControlColor)
                }
                ForEach(tasks) { task in
                    HStack(spacing: 12) {
                        Button {
                            Task { await toggleTask(task) }
                        } label: {
                            Image(systemName: task.status == "done" ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(task.status == "done" ? .green : preferences.accentControlColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .strikethrough(task.status == "done")
                                .foregroundStyle(task.status == "done" ? .secondary : .primary)
                            if let project = projects.first(where: { $0.id == task.project_id }) {
                                Text(project.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                }
                if tasks.isEmpty && !isLoading {
                    Text("尚无任务").foregroundStyle(.secondary)
                }
            } header: {
                Text("我的任务")
            } footer: {
                Text("点击圆圈切换「待办 / 已完成」，变更会实时写入云端。")
            }
            if isLoading {
                Section { ProgressView("同步云端数据…") }
            }
            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Studio 项目与任务")
        .aertexGlassBackButton()
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading || isSaving)
            }
        }
        .sheet(isPresented: $showProjectForm) { projectForm }
        .sheet(isPresented: $showTaskForm) { taskForm }
    }

    private var projectForm: some View {
        NavigationStack {
            Form {
                Section("项目名称") {
                    TextField("例如：AERTEX iOS 开发", text: $projectName)
                }
                Section("项目简介") {
                    TextField("项目简介（选填）", text: $projectSummary, axis: .vertical)
                        .lineLimit(2...5)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.orange) }
                }
            }
            .navigationTitle("新建项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showProjectForm = false }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await createProject() } }
                        .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
        .presentationDetents([.medium, .large])
    }

    private var taskForm: some View {
        NavigationStack {
            Form {
                Section("任务") {
                    TextField("准备做什么？", text: $taskTitle)
                }
                Section("关联项目") {
                    Picker("项目", selection: $selectedProjectId) {
                        Text("不关联项目").tag("")
                        ForEach(projects) { project in
                            Text(project.name).tag(project.id)
                        }
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(.orange) }
                }
            }
            .navigationTitle("新建任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showTaskForm = false }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await createTask() } }
                        .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
        .presentationDetents([.medium, .large])
    }

    private func load() async {
        guard !isLoading && !isSaving else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let p: AERTEXStudioProjectList = auth.nativeGet(
                AERTEXStudioProjectList.self,
                product: .studio,
                path: "/api/native/studio/projects"
            )
            async let t: AERTEXStudioTaskList = auth.nativeGet(
                AERTEXStudioTaskList.self,
                product: .studio,
                path: "/api/native/studio/tasks"
            )
            let loadedProjects = try await p
            let loadedTasks = try await t
            projects = loadedProjects.projects
            tasks = loadedTasks.tasks
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func createProject() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let _: AERTEXStudioMutationResult = try await auth.nativeStudioMutation(
                AERTEXStudioMutationResult.self,
                resource: "projects", method: "POST",
                values: [
                    "name": projectName.trimmingCharacters(in: .whitespacesAndNewlines),
                    "summary": projectSummary,
                    "status": "active",
                    "priority": "normal"
                ]
            )
            showProjectForm = false
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        if !showProjectForm {
            // release the write guard before fetching latest server data
            isSaving = false
            await load()
        }
    }

    private func createTask() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let _: AERTEXStudioMutationResult = try await auth.nativeStudioMutation(
                AERTEXStudioMutationResult.self,
                resource: "tasks", method: "POST",
                values: [
                    "title": taskTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    "project_id": selectedProjectId,
                    "status": "todo",
                    "priority": "normal"
                ]
            )
            showTaskForm = false
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        if !showTaskForm {
            isSaving = false
            await load()
        }
    }

    private func toggleTask(_ task: AERTEXStudioTaskList.Task) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let _: AERTEXStudioMutationResult = try await auth.nativeStudioMutation(
                AERTEXStudioMutationResult.self,
                resource: "tasks",
                method: "PUT",
                id: task.id,
                values: [
                    "title": task.title,
                    "description": task.description ?? "",
                    "priority": task.priority ?? "normal",
                    "project_id": task.project_id ?? "",
                    "due_at": task.due_at ?? "",
                    "status": task.status == "done" ? "todo" : "done"
                ]
            )
            error = nil
            isSaving = false
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
