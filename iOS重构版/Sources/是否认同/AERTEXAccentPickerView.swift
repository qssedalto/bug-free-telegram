import SwiftUI

/// The complete main-site 43-color palette is already stored in AERTEXAccent.
/// Changes are saved to the authenticated account before affecting global UI.
struct AERTEXAccentPickerView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: String = AERTEXAccent.defaultID
    @State private var saving = false
    @State private var error: String?

    private let columns = [
        GridItem(.adaptive(minimum: 105, maximum: 160), spacing: 13)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("使用与 AERTEX 主站相同的 iPhone 配色。保存成功后，所有原生页面立即同步；其他登录设备刷新后也会采用新颜色。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(AERTEXAccent.all) { accent in
                            Button {
                                chosen = accent.id
                            } label: {
                                VStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(accent.color)
                                        .frame(height: 76)
                                        .overlay {
                                            if chosen == accent.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(accent.inkColor)
                                                    .font(.title2)
                                            }
                                        }
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 22)
                                                .strokeBorder(
                                                    chosen == accent.id
                                                        ? preferences.accentControlColor
                                                        : .secondary.opacity(0.18),
                                                    lineWidth: chosen == accent.id ? 3 : 1
                                                )
                                        }
                                    Text(accent.nameZh)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text(accent.hex.uppercased())
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(accent.nameZh)，\(accent.hex)")
                            .accessibilityAddTraits(chosen == accent.id ? .isSelected : [])
                        }
                    }
                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                .padding(20)
                .frame(maxWidth: 850)
                .frame(maxWidth: .infinity)
            }
            .background { LiquidGlassBackdrop() }
            .navigationTitle("AERTEX 主题颜色")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        guard !saving else { return }
                        saving = true
                        Task {
                            let ok = await auth.updateAccent(chosen)
                            if ok {
                                preferences.applyAERTEXAccent(auth.user?.accentId)
                                dismiss()
                            } else {
                                error = auth.errorMessage ?? "保存失败，请重试。"
                            }
                            saving = false
                        }
                    } label: {
                        if saving { ProgressView() } else { Text("保存到 AERTEX ID") }
                    }
                    .disabled(saving || chosen == auth.user?.accentId)
                }
            }
            .interactiveDismissDisabled(saving)
        }
        .onAppear { chosen = auth.user?.accentId ?? AERTEXAccent.defaultID }
    }
}
