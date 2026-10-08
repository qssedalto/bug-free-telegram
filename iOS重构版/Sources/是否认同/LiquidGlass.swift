import SwiftUI
import UIKit

/// Shared Liquid Glass styling for the iOS app.
///
/// On iOS 26 and later this uses the native SwiftUI Liquid Glass APIs.
/// Older systems keep the same hierarchy with an ultra-thin material fallback.
extension View {
    @ViewBuilder
    func liquidGlassSurface(
        cornerRadius: CGFloat = 24,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(
                    .regular.tint(tint).interactive(interactive),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
            } else {
                self.glassEffect(
                    .regular.interactive(interactive),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
            }
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                )
        }
    }

    @ViewBuilder
    func liquidGlassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint).interactive(interactive), in: Capsule())
            } else {
                self.glassEffect(.regular.interactive(interactive), in: Capsule())
            }
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 0.8))
        }
    }

    @ViewBuilder
    func liquidGlassButtonStyle(prominent: Bool = false, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self
                    .buttonStyle(.glassProminent)
                    .tint(tint)
            } else {
                self
                    .buttonStyle(.glass)
                    .tint(tint)
            }
        } else {
            if prominent {
                self
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
            } else {
                self
                    .buttonStyle(.bordered)
                    .tint(tint)
            }
        }
    }
}

/// Groups nearby custom glass surfaces so the system can render and morph them as one material layer.
struct LiquidGlassContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

/// Gives Liquid Glass something meaningful to refract instead of placing it over a flat fill.
struct LiquidGlassBackdrop: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.colorScheme) private var systemColorScheme

    var accent: Color? = nil
    var intense = false

    private var base: Color { Color(uiColor: .systemGroupedBackground) }

    private var primaryAccent: Color { accent ?? preferences.accentColor }

    var body: some View {
        ZStack {
            base

            GeometryReader { proxy in
                let shortest = min(proxy.size.width, proxy.size.height)
                Circle()
                    .fill(primaryAccent.opacity(intense ? 0.34 : 0.22))
                    .frame(width: shortest * 0.95, height: shortest * 0.95)
                    .blur(radius: shortest * 0.16)
                    .offset(x: -shortest * 0.35, y: -shortest * 0.42)

                Circle()
                    .fill(Color.cyan.opacity(systemColorScheme == .light ? 0.16 : 0.11))
                    .frame(width: shortest * 0.76, height: shortest * 0.76)
                    .blur(radius: shortest * 0.18)
                    .offset(x: proxy.size.width - shortest * 0.42, y: shortest * 0.34)

                Circle()
                    .fill(Color.indigo.opacity(preferences.theme == .light ? 0.12 : 0.18))
                    .frame(width: shortest * 0.68, height: shortest * 0.68)
                    .blur(radius: shortest * 0.18)
                    .offset(x: shortest * 0.12, y: proxy.size.height - shortest * 0.28)
            }
            .clipped()

            LinearGradient(
                colors: [
                    Color.white.opacity(preferences.theme == .light ? 0.12 : 0.025),
                    Color.clear,
                    Color.black.opacity(preferences.theme == .light ? 0.02 : 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}
