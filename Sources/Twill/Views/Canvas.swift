import Foundation

/// Draws terminal cells within the size assigned by layout. The interval form
/// requests updates; it does not synchronize with a display refresh signal.
public struct Canvas: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never

    private let interval: TimeInterval?
    private let render: @MainActor (Canvas.Context, Canvas.Size) -> Void

    /// Creates a canvas drawn when the application presents, without scheduling periodic updates.
    public init(_ render: @escaping @MainActor (Canvas.Context, Canvas.Size) -> Void) {
        interval = nil
        self.render = render
    }

    /// Creates a canvas that requests periodic presentations. The interval must be positive and finite.
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
