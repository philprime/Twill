/// Organizes fields and sections vertically with a blank row between entries.
/// Forms do not create a scroll pane or change their controls' keyboard behavior.
public struct Form<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) { content }
    }
}
