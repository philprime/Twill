/// Composes caller-owned empty, error, or loading content without inferring application state.
public struct ContentUnavailableView<Label: View, Description: View, Actions: View>: View {
    private let label: Label
    private let descriptionContent: Description
    private let actions: Actions

    /// Builds a centered label, supporting description, and ordinary interactive actions.
    public init(
        @ViewBuilder label: () -> Label, @ViewBuilder description: () -> Description,
        @ViewBuilder actions: () -> Actions
    ) {
        self.label = label()
        self.descriptionContent = description()
        self.actions = actions()
    }

    /// Centers intrinsic content in offered space without creating a focus boundary.
    public var body: some View {
        VStack(spacing: 1) {
            label.bold()
            descriptionContent.foregroundStyle(.secondary)
            actions
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension ContentUnavailableView where Actions == EmptyView {
    /// Builds an informational unavailable state without actions.
    public init(@ViewBuilder label: () -> Label, @ViewBuilder description: () -> Description) {
        self.init(label: label, description: description, actions: { return EmptyView() })
    }
}

extension ContentUnavailableView where Label == Text, Description == Text, Actions == EmptyView {
    /// Creates a text-only title and supporting description.
    public init(_ title: String, description: String) {
        self.init(label: { return Text(title) }, description: { return Text(description) })
    }
}

extension ContentUnavailableView where Label == Text, Description == EmptyView, Actions == EmptyView {
    /// Creates a title-only unavailable state.
    public init(_ title: String) {
        self.init(label: { return Text(title) }, description: { return EmptyView() })
    }
}
