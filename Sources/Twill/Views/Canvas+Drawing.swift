import Foundation

extension Canvas {
    struct Drawing: PrimitiveDrawing {
        let size: CellSize
        let date: Date
        let render: @MainActor (Canvas.Context, Canvas.Size) -> Void

        func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize {
            CellSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
        }

        func draw(in context: inout DrawingContext) {
            // Primitive drawings are invoked by the UI-actor renderer.
            MainActor.assumeIsolated {
                let surface = Canvas.Context(date: date, drawing: context)
                render(surface, Canvas.Size(width: size.width, height: size.height))
                context = surface.drawing
            }
        }
    }
}
