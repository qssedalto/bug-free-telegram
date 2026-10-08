import SwiftUI

/// AERTEX is now the application. The original "是否认同" experience is
/// one self-contained module inside the native AERTEX product shell.
enum AERTEXSection: Hashable {
    case home
    case services
    case agree
    case account
}

struct AERTEXService: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let address: String

    var url: URL { URL(string: address)! }

    // Only published, independently verified AERTEX web entry points are listed.
    // Until a documented mobile business API exists, these open as web services.
    static let studio = AERTEXService(
        id: "studio", title: "AERTEX Studio",
        subtitle: "个人空间、设置与工作台", symbol: "square.grid.2x2.fill",
        address: "https://qsseda.com/zh-cn/dashboard"
    )
    static let work = AERTEXService(
        id: "work", title: "AERTEX Work",
        subtitle: "独立工作空间", symbol: "rectangle.3.group.fill",
        address: "https://work.qsseda.com"
    )
    static let intelligence = AERTEXService(
        id: "intelligence", title: "AERTEX Intelligence",
        subtitle: "AI 助手与会话", symbol: "sparkles",
        address: "https://gpt.qsseda.com"
    )
    static let watch = AERTEXService(
        id: "watch", title: "AERTEX Watch",
        subtitle: "活动与设备数据", symbol: "applewatch",
        address: "https://aw.qsseda.com"
    )
    static let all = [studio, work, intelligence, watch]
}

struct AERTEXRootView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AERTEXSection = .home

    var body: some View {
        TabView(selection: $selection) {
            AERTEXHomeView(selection: $selection)
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(AERTEXSection.home)

            AERTEXServicesView()
                .tabItem { Label("服务", systemImage: "square.grid.2x2.fill") }
                .tag(AERTEXSection.services)

            ContentView()
                .tabItem { Label("是否认同", systemImage: "questionmark.bubble.fill") }
                .tag(AERTEXSection.agree)

            AERTEXHubView()
                .tabItem { Label("我的", systemImage: "person.crop.circle.fill") }
                .tag(AERTEXSection.account)
        }
        .tint(preferences.accentControlColor)
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task {
                if await auth.refreshAccount() {
                    preferences.applyAERTEXAccent(auth.user?.accentId)
                }
            }
        }
    }
}

struct AERTEXHomeView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @EnvironmentObject private var preferences: AppPreferences
    @Binding var selection: AERTEXSection
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var greetingName: String {
        guard let user = auth.user else { return "AERTEX" }
        if !user.displayName.isEmpty { return user.displayName }
        if !user.username.isEmpty { return user.username }
        return user.email
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LiquidGlassContainer(spacing: 18) {
                    VStack(alignment: .leading, spacing: 22) {
                        hero
                        sectionHeader("工作空间", detail: "AERTEX 服务入口")
                        serviceGrid
                        sectionHeader("我的应用", detail: "原生功能")
                        agreeCard
                        footer
                    }
                    .padding(.horizontal, sizeClass == .regular ? 30 : 18)
                    .padding(.vertical, 20)
                    .frame(maxWidth: 940)
                    .frame(maxWidth: .infinity)
                }
            }
            .background { LiquidGlassBackdrop() }
            .navigationTitle("AERTEX")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selection = .account
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("AERTEX 账户")
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 13) {
                BrandIconView(size: 46)
                    .padding(10)
                    .liquidGlassSurface(cornerRadius: 18, tint: preferences.accentColor.opacity(0.13))
                VStack(alignment: .leading, spacing: 4) {
                    Text("AERTEX")
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    Text("你的个人数字空间")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("欢迎回来，\(greetingName)")
                    .font(.title2.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                Text("从一个地方访问你的 AERTEX 服务与应用。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                selection = .services
            } label: {
                HStack {
                    Label("探索服务", systemImage: "arrow.up.right.square")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .frame(maxWidth: .infinity, minHeight: 46)
                .font(.headline)
            }
            .liquidGlassButtonStyle(prominent: true, tint: preferences.accentControlColor)
        }
        .padding(sizeClass == .regular ? 28 : 22)
        .liquidGlassSurface(cornerRadius: 30, tint: preferences.accentColor.opacity(0.11))
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var serviceGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .regular ? 250 : 150), spacing: 12)], spacing: 12) {
            ForEach(AERTEXService.all) { service in
                Link(destination: service.url) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: service.symbol)
                            .font(.title2)
                            .foregroundStyle(preferences.accentControlColor)
                            .frame(height: 30)
                        Text(service.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(service.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack {
                            Text("网页服务")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                    .padding(17)
                    .liquidGlassSurface(cornerRadius: 22, tint: preferences.accentColor.opacity(0.055), interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var agreeCard: some View {
        Button {
            selection = .agree
        } label: {
            HStack(spacing: 15) {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(preferences.accentControlColor)
                    .frame(width: 48, height: 48)
                    .liquidGlassSurface(cornerRadius: 16, tint: preferences.accentColor.opacity(0.13))
                VStack(alignment: .leading, spacing: 4) {
                    Text("是否认同")
                        .font(.headline.weight(.bold))
                    Text("剧情、选择记录与趣味数据")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(18)
            .liquidGlassSurface(cornerRadius: 23, tint: preferences.accentColor.opacity(0.07), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开是否认同附属功能")
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield")
            Text("通过 AERTEX ID 连接")
            Spacer()
            Text("© TGLab")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }
}

struct AERTEXServicesView: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("连接 AERTEX")
                            .font(.title2.weight(.bold))
                        Text("这里汇集已上线的 AERTEX 产品。支持原生 API 的功能会逐步接入；其他服务会打开对应的官方网页。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 4)

                    ForEach(AERTEXService.all) { service in
                        Link(destination: service.url) {
                            HStack(spacing: 16) {
                                Image(systemName: service.symbol)
                                    .font(.title2)
                                    .foregroundStyle(preferences.accentControlColor)
                                    .frame(width: 38)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(service.title)
                                        .font(.headline)
                                    Text(service.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("在网页中打开")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                            .padding(20)
                            .liquidGlassSurface(cornerRadius: 24, tint: preferences.accentColor.opacity(0.055), interactive: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
            }
            .background { LiquidGlassBackdrop() }
            .navigationTitle("服务")
        }
    }
}
