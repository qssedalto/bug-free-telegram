import SwiftUI

/// Tracks native drill-down destinations independently of the three root tabs.
final class AERTEXTabChrome: ObservableObject {
    @Published var hidden = false
}


/// AERTEX is now the application. The original "是否认同" experience is
/// one self-contained module inside the native AERTEX product shell.
enum AERTEXSection: Hashable {
    case home
    case services
    case account
}

struct AERTEXService: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let address: String

    var url: URL { URL(string: address)! }

    // The URLs are retained only for Safari fallback / the Work web entry point.
    // Studio, Intelligence and Watch now navigate into verified native API views.
    static let studio = AERTEXService(
        id: "studio", title: "AERTEX Studio",
        subtitle: "原生项目、任务与工作台", symbol: "square.grid.2x2.fill",
        address: "https://qsseda.com/zh-cn/dashboard"
    )
    static let work = AERTEXService(
        id: "work", title: "AERTEX Work",
        subtitle: "独立工作空间", symbol: "rectangle.3.group.fill",
        address: "https://work.qsseda.com"
    )
    static let intelligence = AERTEXService(
        id: "intelligence", title: "AERTEX Intelligence",
        subtitle: "原生流式 AI 对话 · 数学公式", symbol: "sparkles",
        address: "https://gpt.qsseda.com"
    )
    static let watch = AERTEXService(
        id: "watch", title: "AERTEX Watch",
        subtitle: "原生活动同步状态", symbol: "applewatch",
        address: "https://aw.qsseda.com"
    )
    static let all = [studio, work, intelligence, watch]
}

/** A native SwiftUI destination for each supported first-party product.
 * Work remains an explicit Safari link until its own mobile API is ready.
 */
struct AERTEXServiceLink<LabelContent: View>: View {
    @EnvironmentObject private var tabChrome: AERTEXTabChrome
    let service: AERTEXService
    let label: () -> LabelContent

    init(service: AERTEXService, @ViewBuilder label: @escaping () -> LabelContent) {
        self.service = service
        self.label = label
    }

    var body: some View {
        if service.id == "work" {
            Link(destination: service.url, label: label)
        } else {
            NavigationLink(destination: destination
                .onAppear { tabChrome.hidden = true }
                .onDisappear { tabChrome.hidden = false }, label: label)
        }
    }

    @ViewBuilder private var destination: some View {
        switch service.id {
        case "studio": AERTEXStudioNativeView()
        case "intelligence": AERTEXIntelligenceNativeView()
        case "watch": AERTEXWatchNativeView()
        default: Text("服务暂不可用")
        }
    }
}

struct AERTEXRootView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AERTEXSection = .home
    @State private var showAgree = false
    @StateObject private var tabChrome = AERTEXTabChrome()
    @State private var dragSelection: AERTEXSection?

    var body: some View {
        TabView(selection: $selection) {
            AERTEXHomeView(selection: $selection, showAgree: $showAgree)
                .toolbar(.hidden, for: .tabBar)
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(AERTEXSection.home)

            AERTEXServicesView(showAgree: $showAgree)
                .toolbar(.hidden, for: .tabBar)
                .tabItem { Label("服务", systemImage: "square.grid.2x2.fill") }
                .tag(AERTEXSection.services)

            AERTEXHubView()
                .toolbar(.hidden, for: .tabBar)
                .tabItem { Label("我的", systemImage: "person.crop.circle.fill") }
                .tag(AERTEXSection.account)
        }
        // iOS 27 floating capsule: hide the legacy opaque system bar while
        // retaining TabView's navigation stacks and per-tab state.
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !tabChrome.hidden {
                capsuleTabBar
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
            }
        }
        .environmentObject(tabChrome)
        .tint(preferences.accentControlColor)
        .fullScreenCover(isPresented: $showAgree) {
            ContentView(presentedFromAERTEX: true)
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task {
                if await auth.refreshAccount() {
                    preferences.applyAERTEXAccent(auth.user?.accentId)
                }
            }
        }
    }

    private let tabs: [AERTEXSection] = [.home, .services, .account]

    private var capsuleTabBar: some View {
        LiquidGlassContainer(spacing: 8) {
            GeometryReader { geometry in
                let itemWidth = max(1, (geometry.size.width - 14) / 3)
                HStack(spacing: 0) {
                    capsuleItem(.home, label: "首页", symbol: "house.fill")
                    capsuleItem(.services, label: "服务", symbol: "square.grid.2x2.fill")
                    capsuleItem(.account, label: "我的", symbol: "person.crop.circle.fill")
                }
                .padding(7)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
                .liquidGlassCapsule(interactive: true)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { gesture in
                            let raw = Int((gesture.location.x - 7) / itemWidth)
                            let index = min(2, max(0, raw))
                            let next = tabs[index]
                            if dragSelection != next {
                                dragSelection = next
                            }
                        }
                        .onEnded { gesture in
                            let raw = Int((gesture.location.x - 7) / itemWidth)
                            let index = min(2, max(0, raw))
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                selection = tabs[index]
                            }
                            dragSelection = nil
                        }
                )
            }
            .frame(height: 64)
            .frame(maxWidth: 470)
            .frame(maxWidth: .infinity)
        }
    }

    private func capsuleItem(
        _ item: AERTEXSection, label: String, symbol: String
    ) -> some View {
        let active = (dragSelection ?? selection) == item
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                selection = item
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                Text(label).font(.caption.weight(active ? .bold : .medium))
            }
            .foregroundStyle(active ? preferences.accentControlColor : .secondary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                if active {
                    Capsule().fill(preferences.accentColor.opacity(0.17))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}

struct AERTEXHomeView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @EnvironmentObject private var preferences: AppPreferences
    @Binding var selection: AERTEXSection
    @Binding var showAgree: Bool
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
                AERTEXServiceLink(service: service) {
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
                            Text(service.id == "work" ? "网页服务" : "原生服务")
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
            showAgree = true
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
    @Binding var showAgree: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("连接 AERTEX")
                            .font(.title2.weight(.bold))
                        Text("Studio 工作台、Intelligence 原生 AI 对话和 Watch 同步状态均已接入原生 API；Work 暂时由 Safari 打开。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 4)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("内置应用")
                            .font(.headline)
                            .padding(.horizontal, 2)
                        Button {
                            showAgree = true
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "questionmark.bubble.fill")
                                    .font(.title2)
                                    .foregroundStyle(preferences.accentControlColor)
                                    .frame(width: 38)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("是否认同")
                                        .font(.headline)
                                    Text("原生趣味模块 · 剧情与数据")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                            .padding(20)
                            .liquidGlassSurface(cornerRadius: 24, tint: preferences.accentColor.opacity(0.08), interactive: true)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("在线服务")
                        .font(.headline)
                        .padding(.horizontal, 2)

                    ForEach(AERTEXService.all) { service in
                        AERTEXServiceLink(service: service) {
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
                                    Text(service.id == "work" ? "在 Safari 中打开" : "打开原生页面")
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
