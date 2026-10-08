import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var auth: AERTEXAuthStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmDefaults = false
    @State private var showAERTEX = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        BrandIconView(size: 72)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("是否认同").font(.title2.weight(.black))
                            Text("版本 1.1.0 · iOS 重构版").font(.caption).foregroundStyle(.secondary)
                            Text("© 天国智造 · TGLab").font(.caption.weight(.bold))
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("AERTEX 账户") {
                    Button { showAERTEX = true } label: {
                        Label("账户与服务中心", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    if let user = auth.user {
                        LabeledContent("显示名称", value: user.displayName)
                        if !user.username.isEmpty {
                            LabeledContent("用户名", value: user.username)
                        }
                        LabeledContent("邮箱", value: user.email)
                        LabeledContent("状态", value: user.status == "active" ? "正常" : user.status)
                    } else {
                        Label("当前会话不可用", systemImage: "person.crop.circle.badge.exclamationmark")
                    }

                    Button("退出 AERTEX", role: .destructive) {
                        Task {
                            await auth.logout()
                            dismiss()
                        }
                    }
                }

                Section("AERTEX 主题色") {
                    let accent = preferences.currentAERTEXAccent

                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(accent.color)
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.34),
                                    Color.clear,
                                    Color.black.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 23, weight: .bold))
                                .foregroundStyle(accent.inkColor.opacity(0.92))
                        }
                        .frame(width: 58, height: 58)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.primary.opacity(0.10), lineWidth: 0.7)
                        )
                        .shadow(color: accent.color.opacity(0.22), radius: 10, y: 5)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(accent.displayName(english: preferences.english))
                                .font(.headline.weight(.bold))
                            Text(accent.hex.uppercased())
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("与 AERTEX 主站同步")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundStyle(preferences.accentControlColor)
                    }
                    .padding(.vertical, 5)

                    if !accent.modelSummary.isEmpty {
                        LabeledContent("配色来源", value: accent.modelSummary)
                            .font(.caption)
                    }

                    Button {
                        Task { await syncAERTEXAppearance() }
                    } label: {
                        Label("立即同步主站主题色", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Link(destination: URL(string: "https://qsseda.com/zh-cn/settings/appearance")!) {
                        Label("前往 AERTEX 主站调整颜色", systemImage: "safari")
                    }

                    Text("主题色由 AERTEX 主站统一管理。请前往主站「设置 → 主题与外观」调整颜色；返回 App 后会自动同步。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("金额与锚点") {
                    DatePicker("起始日期", selection: $preferences.startDate, displayedComponents: .date)
                    TextField("初始金额", text: $preferences.initialAmount)
                        .keyboardType(.decimalPad)
                    Text("默认锚点为 2023-06-19、初始金额为 1008；2023-06-21 的计算结果为 1111。")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("标题与剧情") {
                    TextField("主界面标题", text: $preferences.windowTitle, axis: .vertical).lineLimit(1...2)
                    TextField("中心问题", text: $preferences.question, axis: .vertical).lineLimit(1...4)
                    TextField("自定义剧情文字", text: $preferences.customStory, axis: .vertical).lineLimit(3...8)
                    Toggle("中性/虚构角色模式", isOn: $preferences.neutralMode)
                    Toggle("英文界面", isOn: $preferences.english)
                }

                Section("外观") {
                    Picker("主题", selection: $preferences.theme) {
                        ForEach(AppTheme.allCases) { Text($0.rawValue).tag($0) }
                    }
                    VStack(alignment: .leading) {
                        HStack { Text("字号缩放"); Spacer(); Text("\(Int(preferences.fontScale * 100))%").monospacedDigit() }
                        Slider(value: $preferences.fontScale, in: 0.75...1.75, step: 0.05)
                    }
                    Toggle("高对比度", isOn: $preferences.highContrast)
                }

                Section("动效与反馈") {
                    Toggle("减少动画", isOn: $preferences.reduceMotion)
                    Toggle("启用音效", isOn: $preferences.soundEnabled)
                    Text("iOS 会自动遵循系统的动态字体、减少动态效果和增强对比度辅助功能。")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("数据与隐私") {
                    Label("设置、签到、每日快照和历史选择仅保存在本机。", systemImage: "lock.shield.fill")
                    Label("汇率请求不上传剧情与欠款数据。", systemImage: "network.badge.shield.half.filled")
                }

                Section {
                    Button("恢复默认设置", role: .destructive) { confirmDefaults = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background { LiquidGlassBackdrop() }
            .navigationTitle("设置")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showAERTEX) { AERTEXHubView() }
        .alert("恢复默认设置？", isPresented: $confirmDefaults) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) { preferences.restoreDefaults() }
        } message: { Text("这会恢复标题、问题、主题和金额参数；剧情历史不会被删除。AERTEX 主题色不会被本地重置。") }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            Task { await syncAERTEXAppearance() }
        }
    }

    @MainActor
    private func syncAERTEXAppearance() async {
        guard await auth.refreshAccount() else { return }
        preferences.applyAERTEXAccent(auth.user?.accentId)
    }
}
