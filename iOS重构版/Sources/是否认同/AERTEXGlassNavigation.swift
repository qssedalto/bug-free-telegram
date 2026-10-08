import SwiftUI

/// iOS 27 explicit round Liquid Glass chevron, rather than relying on an
/// OS-selected bare navigation glyph. NavigationStack remains responsible
/// for the destination stack and normal toolbar placement.
private struct AERTEXGlassBackModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tint) private var tint

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(tint ?? .primary)
                            .frame(width: 40, height: 40)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .liquidGlassCapsule(interactive: true)
                    .accessibilityLabel("返回")
                }
            }
    }
}

extension View {
    func aertexGlassBackButton() -> some View {
        modifier(AERTEXGlassBackModifier())
    }
}
