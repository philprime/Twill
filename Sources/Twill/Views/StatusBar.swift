/// A one-cell-high horizontal region for ordinary status content and key hints.
/// Content controls retain their usual focus and action behavior.
public struct StatusBar<Content: View>: View {
    private let content: Content
    private let spacing: Int

    /// Creates a status row with nonnegative spacing. Use Spacer for flexible separation.
    public init(spacing: Int = 2, @ViewBuilder content: () -> Content) {
        precondition(spacing >= 0, "Status spacing must not be negative")
        self.spacing = spacing
        self.content = content()
    }

    /// Fills offered width and clips excess content without registering hint actions.
    public var body: some View {
        HStack(alignment: .top, spacing: spacing) { content }
            .frame(height: 1, maxWidth: .infinity, alignment: .leading)
    }
}
