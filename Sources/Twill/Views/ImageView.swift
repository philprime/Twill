/// Presents image data using injected terminal capabilities or caller-provided fallback content.
public struct ImageView<Fallback: View>: View {
    /// Primitive content rendered directly by the runtime.
    public typealias Body = Never
    private let image: Image
    private let size: CellSize
    private let contentMode: ImageContentMode
    private let fallback: Fallback

    /// Reserves a cell rectangle, fitting pixels by default. Negative dimensions clamp to zero.
    /// Unsupported terminals mount the fallback instead of emitting graphics commands.
    public init(
        _ image: Image, width: Int, height: Int, contentMode: ImageContentMode = .aspectFit,
        @ViewBuilder fallback: () -> Fallback
    ) {
        self.image = image
        self.size = CellSize(width: max(0, width), height: max(0, height))
        self.contentMode = contentMode
        self.fallback = fallback()
    }
}

extension ImageView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .image(ImageDescription(image: image, size: size, contentMode: contentMode, fallback: fallback))
    }
}

struct SupportedImageView: View, PrimitiveView {
    typealias Body = Never
    let drawing: ImageDrawing
    func makeDescription() -> ViewDescription { .drawing(drawing) }
}
