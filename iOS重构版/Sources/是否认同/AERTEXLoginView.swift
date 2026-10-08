import SwiftUI
import UIKit

struct AERTEXLoginView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @EnvironmentObject private var preferences: AppPreferences

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var isRestoring = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        ZStack {
            LiquidGlassBackdrop(accent: preferences.accentColor, intense: true)

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 52)

                    BrandIconView(size: 82)

                    VStack(spacing: 8) {
                        Text("AERTEX")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(2.2)
                            .foregroundStyle(.secondary)
                        Text("登录以继续使用「是否认同」")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .multilineTextAlignment(.center)
                        Text("使用你的 AERTEX 账户验证身份。密码只用于本次 HTTPS 登录，不会保存在设备上。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 14) {
                        TextField("AERTEX 邮箱", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.username)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .padding(15)
                            .liquidGlassSurface(
                                cornerRadius: 18,
                                tint: preferences.accentColor.opacity(0.055),
                                interactive: true
                            )

                        SecureField("密码", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { submit() }
                            .padding(15)
                            .liquidGlassSurface(
                                cornerRadius: 18,
                                tint: preferences.accentColor.opacity(0.055),
                                interactive: true
                            )

                        if let error = auth.errorMessage, !error.isEmpty {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: submit) {
                            HStack(spacing: 10) {
                                if isSubmitting {
                                    ProgressView()
                                }
                                Text(isSubmitting ? "正在登录…" : "登录 AERTEX")
                                    .font(.headline.weight(.bold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .padding(.horizontal, 12)
                        }
                        .liquidGlassButtonStyle(prominent: true, tint: preferences.accentControlColor)
                        .disabled(isSubmitting || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                        .opacity(isSubmitting ? 0.8 : 1)
                    }
                    .frame(maxWidth: 460)

                    if auth.errorMessage != nil {
                        Button {
                            guard !isRestoring else { return }
                            isRestoring = true
                            Task {
                                await auth.restore()
                                isRestoring = false
                            }
                        } label: {
                            Label(isRestoring ? "正在重连…" : "重试恢复现有会话", systemImage: "arrow.clockwise")
                        }
                        .disabled(isRestoring)
                    }

                    VStack(spacing: 7) {
                        Label("由 auth.qsseda.com 安全验证", systemImage: "lock.shield.fill")
                        Text("登录成功后仅将会话刷新令牌保存到 iOS Keychain。")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func submit() {
        guard !isSubmitting else { return }
        focusedField = nil
        isSubmitting = true
        Task {
            let ok = await auth.login(email: email, password: password)
            if ok { password = "" }
            isSubmitting = false
        }
    }
}
