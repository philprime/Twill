/// Displays an image in a terminal-cell rectangle using the Kitty graphics protocol.
/// Requires a compatible terminal such as Ghostty. Width and height are cell counts,
/// not pixels. The terminal scales the image to this rectangle.
public struct ImageView: View {
    public typealias Body = Never
    private let image: Image
    private let size: CellSize

    public init(_ image: Image, width: Int, height: Int) {
        self.image = image
        size = CellSize(width: max(0, width), height: max(0, height))
    }
}

extension ImageView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .drawing(ImageDrawing(image: image, size: size))
    }
}

private struct ImageDrawing: PrimitiveDrawing {
    let image: Image
    let size: CellSize

    func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize {
        proposal.constrain(size)
    }

    func draw(in context: inout DrawingContext) {
        context.drawImage(
            image.data,
            size: CellSize(
                width: min(size.width, context.regionSize.width),
                height: min(size.height, context.regionSize.height)))
    }
}
