import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDefaults = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "questionmark.bubble.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(preferences.accentControlColor)
                            .frame(width: 60, height: 60)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("是否认同").font(.title2.weight(.bold))
                            AERTEXBrandedText("AERTEX · 附属功能")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("剧情与历史记录仅保存在本机")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
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
            .navigationTitle("是否认同设置")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.large])
        .alert("恢复默认设置？", isPresented: $confirmDefaults) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) { preferences.restoreDefaults() }
        } message: { AERTEXBrandedText("这会恢复「是否认同」的标题、问题和金额参数；剧情历史不会被删除。不会修改 AERTEX 账户及主站主题色。") }
    }
}
