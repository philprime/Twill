import Foundation

/// Draws terminal cells within the size assigned by layout. The interval form
/// requests updates; it does not synchronize with a display refresh signal.
public struct Canvas: View {
    public typealias Body = Never

    private let interval: TimeInterval?
    private let render: @MainActor (Canvas.Context, Canvas.Size) -> Void

    public init(_ render: @escaping @MainActor (Canvas.Context, Canvas.Size) -> Void) {
        interval = nil
        self.render = render
    }

    public init(interval: TimeInterval, render: @escaping @MainActor (Canvas.Context, Canvas.Size) -> Void) {
        precondition(interval.isFinite && interval > 0, "Canvas interval must be positive and finite")
        self.interval = interval
        self.render = render
    }
}

extension Canvas: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .canvas(interval: interval, render: render)
    }
}
