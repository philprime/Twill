/// Presents a separate keyboard scope while retaining the underlying mounted view.
public struct SheetView<Content: View, Presented: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let content: Content
    private let isPresented: Binding<Bool>
    private let presentedContent: @MainActor () -> Presented

    init(content: Content, isPresented: Binding<Bool>, presentedContent: @escaping @MainActor () -> Presented) {
        self.content = content
        self.isPresented = isPresented
        self.presentedContent = presentedContent
    }
}

extension View {
    /// Presents content in a modal keyboard scope while the binding is true.
    /// The underlying view remains mounted; dismissing restores its focus.
    public func sheet<Presented: View>(
        isPresented: Binding<Bool>, @ViewBuilder content: @escaping @MainActor () -> Presented
    ) -> SheetView<Self, Presented> {
        SheetView(content: self, isPresented: isPresented, presentedContent: content)
    }
}

extension SheetView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .sheet(base: content, isPresented: isPresented, content: { presentedContent() })
    }
}
