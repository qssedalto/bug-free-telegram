import Foundation

// SwiftPM supplies Bundle.module, but a direct Xcode app target does not.
// XcodeGen copies the original Resources directory into the app bundle.
extension Bundle {
    static var module: Bundle { .main }
}
