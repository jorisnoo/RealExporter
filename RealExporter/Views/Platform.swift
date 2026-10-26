import SwiftUI
#if os(iOS)
import UIKit
#endif

extension Color {
    /// Fill of the rounded cards that group each screen's content.
    static var cardBackground: Color {
        #if os(macOS)
        Color(.controlBackgroundColor)
        #else
        Color(.secondarySystemBackground)
        #endif
    }

    static var cardBorder: Color {
        #if os(macOS)
        Color(.separatorColor)
        #else
        Color(.separator)
        #endif
    }
}

extension CGFloat {
    /// Space around each screen's content; a phone can't spare the Mac's margins.
    static var screenPadding: CGFloat {
        #if os(macOS)
        40
        #else
        20
        #endif
    }
}

extension View {
    /// The rounded card that groups each screen's content.
    func cardStyle(cornerRadius: CGFloat = 12) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.cardBackground)
        )
    }

    /// Keeps the Mac window from shrinking below a usable size. The screen
    /// sets the size on iOS.
    func windowMinSize(width: CGFloat, height: CGFloat) -> some View {
        #if os(macOS)
        frame(minWidth: width, minHeight: height)
        #else
        self
        #endif
    }
}

/// Keeps a user-picked, security-scoped URL readable and writable until this
/// is released. Needed on iOS and in the sandbox; a no-op for plain URLs.
nonisolated final class ScopedAccess: Sendable {
    let url: URL
    private let started: Bool

    init(_ url: URL) {
        self.url = url
        started = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if started {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

#if os(iOS)
extension URL {
    /// Opens the Files app at this folder.
    func showInFiles() {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return }
        components.scheme = "shareddocuments"
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }
}
#endif
