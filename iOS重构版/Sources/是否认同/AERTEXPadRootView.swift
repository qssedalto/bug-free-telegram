import SwiftUI
import UIKit

/// An adaptive native iPad workspace, deliberately sharing the same API-backed
/// screens, authentication and feature models as the iPhone application.
private enum AERTEXPadSection: Hashable {
    case home, services, studio, intelligence, watch, account, agree
}

struct AERTEXPadRootView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.scenePhase) private var scenePhase

    @State private var selection: AERTEXPadSection? = .home
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @StateObject private var tabChrome = AERTEXTabChrome()

    // Existing Home/Services panels use these bindings on iPhone. On iPad
    // they select the corresponding workspace detail instead of presenting
    // a second, phone-sized tab bar or full-screen modal.
    private var sectionBinding: Binding<AERTEXSection> {
        Binding(
            get: {
                switch selection {
                case .services: return .services
                case .account: return .account
                default: return .home
                }
            },
            set: { newValue in
                switch newValue {
                case .home: selection = .home
                case .services: selection = .services
                case .account: selection = .account
                }
            }
        )
    }

    private var agreeBinding: Binding<Bool> {
        Binding(
            get: { selection == .agree },
            set: { if $0 { selection = .agree } else if selection == .agree { selection = .home } }
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            List(selection: $selection) {
                Section("工作空间") {
                    sidebarRow("首页", systemImage: "house.fill", section: .home)
                    sidebarRow("全部服务", systemImage: "square.grid.2x2.fill", section: .services)
                }

                Section("原生服务") {
                    sidebarRow("Intelligence", systemImage: "sparkles", section: .intelligence)
                    sidebarRow("Studio", systemImage: "square.stack.3d.up.fill", section: .studio)
                    sidebarRow("Watch", systemImage: "applewatch", section: .watch)
                    Link(destination: AERTEXService.work.url) {
                        Label("Work · Safari", systemImage: "rectangle.3.group.fill")
                    }
                }

                Section("我的 AERTEX") {
                    sidebarRow("账户与外观", systemImage: "person.crop.circle.fill", section: .account)
                    sidebarRow("是否认同", systemImage: "questionmark.bubble.fill", section: .agree)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background { LiquidGlassBackdrop() }
            .navigationTitle("AERTEX")
            .navigationSplitViewColumnWidth(min: 230, ideal: 275, max: 340)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BrandIconView(size: 28)
                        .accessibilityHidden(true)
                }
            }
        } detail: {
            Group {
                switch selection ?? .home {
                case .home:
                    AERTEXHomeView(selection: sectionBinding, showAgree: agreeBinding)
                case .services:
                    AERTEXServicesView(showAgree: agreeBinding)
                case .studio:
                    NavigationStack { AERTEXStudioNativeView() }
                case .intelligence:
                    NavigationStack { AERTEXIntelligenceNativeView() }
                case .watch:
                    NavigationStack { AERTEXWatchNativeView() }
                case .account:
                    AERTEXHubView()
                case .agree:
                    ContentView(presentedFromAERTEX: false)
                }
            }
            .id(selection)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { LiquidGlassBackdrop() }
        }
        .navigationSplitViewStyle(.balanced)
        .environmentObject(tabChrome)
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

    private func sidebarRow(
        _ title: String, systemImage: String, section: AERTEXPadSection
    ) -> some View {
        Label(title, systemImage: systemImage)
            .tag(section)
            .accessibilityLabel(title)
    }
}
