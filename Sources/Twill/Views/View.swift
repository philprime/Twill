/// A declarative description of terminal content, evaluated on the UI actor.
@MainActor
public protocol View {
    associatedtype Body: View
    var body: Body { get }
}

extension Never: View {
    public typealias Body = Never
}

extension View where Body == Never {
    /// Primitive views are rendered directly rather than by evaluating a body.
    public var body: Never { fatalError("Primitive views do not have a body") }
}
