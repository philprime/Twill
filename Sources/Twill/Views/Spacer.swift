/// Flexible empty space along the nearest stack's main axis, or both axes outside a stack.
public struct Spacer: View, PrimitiveView {
    /// Primitive content rendered directly by the runtime.
    public typealias Body = Never
    private let minimum: Int

    /// Creates space with a nonnegative intrinsic minimum in terminal cells.
    public init(minLength: Int = 0) {
        precondition(minLength >= 0, "Spacer minimum must not be negative")
        minimum = minLength
    }

    func makeDescription() -> ViewDescription { .spacer(minimum) }
}
