import SwiftUI

/// Native account entry point. AERTEX remains the identity/API service;
/// the app is its client rather than an HTTP server exposed on the iPhone.
struct AERTEXHubView: View {
    var presentedAsSheet = false
    @EnvironmentObject private var auth: AERTEXAuthStore
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var syncMessage: String?
    @State private var isSyncing = false
    @State private var confirmSignOut = false
    @State private var showEditName = false
    @State private var editedName = ""

    private var accountName: String {
        guard let user = auth.user else { return "AERTEX ID" }
        return user.displayName.isEmpty ? (user.username.isEmpty ? user.email : user.username) : user.displayName
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LiquidGlassContainer(spacing: 16) {
                    VStack(alignment: .leading, spacing: 18) {
                        accountCard
                        connectionCard
                        appearanceCard
                        actionsCard
                        Button(role: .destructive) { confirmSignOut = true } label: {
                            Label("退出 AERTEX ID", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .liquidGlassButtonStyle()
                        Text("AERTEX 是主应用；「是否认同」是内置附属模块。账户信息及强调色来自 AERTEX，剧情与历史数据仍保留在设备上。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                    }
                    .padding(18)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
            }
            .background { LiquidGlassBackdrop() }
            .navigationTitle("我的 AERTEX")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if presentedAsSheet {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { dismiss() }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showEditName) {
            editNameSheet
        }
        .alert("退出 AERTEX？", isPresented: $confirmSignOut) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                Task { await auth.logout() }
            }
        } message: {
            Text("退出后需要重新登录。保存在本机的「是否认同」剧情及历史记录不会被删除。")
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(preferences.accentControlColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(accountName)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                    Text(auth.user?.email ?? "未连接")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }

            Button {
                editedName = auth.user?.displayName ?? ""
                auth.errorMessage = nil
                showEditName = true
            } label: {
                Label("修改 AERTEX 显示名称", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(preferences.accentControlColor)

            Divider()

            HStack {
                Label(auth.isAuthenticated ? "账户已连接" : "尚未连接", systemImage: auth.isAuthenticated ? "checkmark.shield.fill" : "wifi.slash")
                    .foregroundStyle(auth.isAuthenticated ? .green : .orange)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let user = auth.user {
                    Text(user.role)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(22)
        .liquidGlassSurface(cornerRadius: 28, tint: preferences.accentColor.opacity(0.10))
    }

    private var editNameSheet: some View {
        NavigationStack {
            Form {
                Section("显示名称") {
                    TextField("新的显示名称", text: $editedName)
                        .textContentType(.nickname)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                    Text("修改后会立即同步到 AERTEX 账户。用户名、邮箱及权限不会改变。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let message = auth.errorMessage, !message.isEmpty {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("编辑账户资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showEditName = false }
                        .disabled(auth.isUpdatingProfile)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await auth.updateDisplayName(editedName) {
                                showEditName = false
                            }
                        }
                    } label: {
                        if auth.isUpdatingProfile {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(auth.isUpdatingProfile || editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(auth.isUpdatingProfile)
        }
        .presentationDetents([.medium, .large])
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("连接与同步", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                .font(.headline)
                .foregroundStyle(preferences.accentControlColor)
            HStack {
                Text("服务")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("auth.qsseda.com")
                    .monospaced()
                    .font(.caption)
                    .lineLimit(1)
            }
            HStack {
                Text("最近同步")
                    .foregroundStyle(.secondary)
                Spacer()
                if let date = auth.lastSyncedAt {
                    Text(date, style: .relative)
                } else {
                    Text("尚无记录")
                }
            }
            .font(.subheadline)
            if let syncMessage {
                Text(syncMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task { await synchronize() }
            } label: {
                HStack {
                    if isSyncing || auth.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("同步账户及主站主题")
                        .frame(maxWidth: .infinity)
                }
                .font(.headline)
                .frame(minHeight: 44)
            }
            .liquidGlassButtonStyle(prominent: true, tint: preferences.accentControlColor)
            .disabled(isSyncing || auth.isRefreshing)
        }
        .padding(20)
        .liquidGlassSurface(cornerRadius: 24, tint: preferences.accentColor.opacity(0.055))
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("主题与外观", systemImage: "paintpalette.fill")
                .font(.headline)
                .foregroundStyle(preferences.accentControlColor)
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(preferences.accentColor)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "checkmark")
                            .foregroundStyle(preferences.accentInkColor)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(preferences.accentName)
                        .font(.subheadline.weight(.bold))
                    Text(preferences.currentAERTEXAccent.hex.uppercased())
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(preferences.accentControlColor)
            }
            Text("强调色跟随 AERTEX 主站；深浅模式跟随 iOS 系统。颜色请到主站调整，再返回 App 同步。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .liquidGlassSurface(cornerRadius: 24, tint: preferences.accentColor.opacity(0.055))
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("AERTEX 服务", systemImage: "square.grid.2x2.fill")
                .font(.headline)
                .foregroundStyle(preferences.accentControlColor)
            serviceLink("AERTEX 主站", subtitle: "访问工作台与服务", icon: "square.grid.2x2", url: "https://qsseda.com")
            Divider()
            serviceLink("账户中心", subtitle: "修改账户及安全设置", icon: "person.crop.circle", url: "https://auth.qsseda.com/account")
            Divider()
            serviceLink("主题与外观", subtitle: "颜色由主站统一管理", icon: "paintpalette", url: "https://qsseda.com/zh-cn/settings/appearance")
        }
        .padding(20)
        .liquidGlassSurface(cornerRadius: 24, tint: preferences.accentColor.opacity(0.055))
    }

    private func serviceLink(_ title: String, subtitle: String, icon: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 28)
                    .font(.title3)
                    .foregroundStyle(preferences.accentControlColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func synchronize() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        let success = await auth.refreshAccount()
        if success {
            preferences.applyAERTEXAccent(auth.user?.accentId)
            syncMessage = "账户已同步，主题色已更新。"
        } else {
            syncMessage = "当前无法完成同步。请检查网络连接或重新登录。"
        }
    }
}
