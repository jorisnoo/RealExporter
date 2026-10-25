import SwiftUI

/// A vertical scroll view that makes the window grow to fit its content.
///
/// A plain `ScrollView` doesn't report its content's size as a minimum, so a
/// window sized to its content stays small and clips controls that can't
/// shrink, like segmented pickers. This one asks for the content's ideal size
/// instead, and only scrolls when the screen is too short to show it all.
struct FittingScrollView<Content: View>: View {
    @ViewBuilder var content: Content

    #if os(macOS)
    /// Leaves room for the title bar and the button bar below the scroll view.
    private var maxHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 600) - 160
    }

    var body: some View {
        IdealMinimumLayout(maxHeight: maxHeight) {
            ScrollView {
                content
            }
        }
    }
    #else
    var body: some View {
        ScrollView {
            content
        }
    }
    #endif
}

#if os(macOS)
/// Sizes its only child to at least the child's ideal size, with the height
/// capped at `maxHeight`, and fills any extra space offered beyond that.
private struct IdealMinimumLayout: Layout {
    var maxHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal = subviews[0].sizeThatFits(.unspecified)
        return CGSize(
            width: max(proposal.width ?? 0, ideal.width),
            height: max(proposal.height ?? 0, min(ideal.height, maxHeight))
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}
#endif
