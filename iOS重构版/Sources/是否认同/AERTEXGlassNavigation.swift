import SwiftUI

/// Keep the real iOS 26/27 system navigation back control. Apple renders the
/// compact, chevron-only back action in native circular Liquid Glass; keeping
/// it system-owned also preserves interactive edge-swipe navigation,
/// accessibility, and automatic light/dark material adaptations.
private struct AERTEXGlassBackModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarRole(.editor)
            .toolbar(.visible, for: .navigationBar)
    }
}

extension View {
    func aertexGlassBackButton() -> some View {
        modifier(AERTEXGlassBackModifier())
    }
}
