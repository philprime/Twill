/// Presents a separate keyboard scope while retaining the underlying mounted view.
public struct SheetView<Content: View, Presented: View>: View {
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
