/// Two horizontal panes with deterministic fixed/flexible allocation.
/// Narrow proposals clip excess content without changing keyboard traversal.
public struct SplitView<Leading: View, Trailing: View>: View {
    /// Primitive content rendered directly by the runtime.
    public typealias Body = Never
    private let leading: Leading
    private let trailing: Trailing
    private let layout: SplitLayout

    /// Builds leading and trailing panes with nonnegative widths and spacing.
    /// Empty panes reserve neither width nor a gap; retained panes keep their identity.
    public init(
        leadingWidth: SplitPaneWidth = .flexible(), trailingWidth: SplitPaneWidth = .flexible(), spacing: Int = 1,
        @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing
    ) {
        precondition(spacing >= 0, "Split spacing must not be negative")
        self.layout = SplitLayout(columns: [leadingWidth.column, trailingWidth.column], spacing: spacing)
        self.leading = leading()
        self.trailing = trailing()
    }
}

extension SplitView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .split(panes: [SplitPane(content: leading), SplitPane(content: trailing)], layout)
    }
}

/// Each pane owns one layout slot even when its public content is transparent.
private struct SplitPane<Content: View>: View, PrimitiveView {
    typealias Body = Never
    let content: Content

    func makeDescription() -> ViewDescription {
        .group(
            children: [content], layout: FrameLayout(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading))
    }
}
