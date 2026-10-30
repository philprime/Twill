/// A one-cell-thick terminal separator that spans its stack's minor axis.
public struct Divider: View, PrimitiveView {
    /// Primitive content rendered directly by the runtime.
    public typealias Body = Never
    private let axis: Axis?

    /// Creates a separator with an optional explicit direction.
    /// Automatic direction is horizontal outside a stack.
    public init(_ axis: Axis? = nil) { self.axis = axis }

    func makeDescription() -> ViewDescription { .divider(axis) }
}
