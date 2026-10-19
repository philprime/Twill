/// Draws a Swift-owned RGBA bitmap in the terminal space assigned by layout.
/// Requires a Kitty graphics-compatible terminal. No PNG encoding is performed.
/// State changes request presentation; use a TimelineView for explicit animation.
public struct PixelCanvas: View {
    private let pixelsPerCell: PixelSize
    private let render: @MainActor (inout Context, PixelSize) -> Void

    /// Creates a pixel canvas. The positive sampling resolution per terminal cell
    /// is explicit, not a measurement of the terminal font. The terminal scales
    /// the bitmap to the allocated cell rectangle.
    public init(
        pixelsPerCell: PixelSize = PixelSize(width: 8, height: 16),
        render: @escaping @MainActor (inout Context, PixelSize) -> Void
    ) {
        precondition(pixelsPerCell.width > 0 && pixelsPerCell.height > 0)
        self.pixelsPerCell = pixelsPerCell
        self.render = render
    }
    /// The bitmap surface fills the remaining space offered by enclosing stacks.
    public var body: some View {
        Surface(pixelsPerCell: pixelsPerCell, render: render)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension PixelCanvas {
    struct Surface: View, PrimitiveView {
        typealias Body = Never
        let pixelsPerCell: PixelSize
        let render: @MainActor (inout Context, PixelSize) -> Void

        func makeDescription() -> ViewDescription {
            .drawing(Drawing(pixelsPerCell: pixelsPerCell, render: render))
        }
    }
}
