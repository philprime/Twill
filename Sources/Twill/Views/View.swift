/// A declarative description of terminal content, evaluated on the UI actor.
@MainActor
public protocol View {
    /// The concrete view description returned when composing this view.
    associatedtype Body: View
    /// The content that describes this view. Primitive views are rendered without evaluating a body.
    var body: Body { get }
}

extension Never: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
}

extension View where Body == Never {
    /// Primitive views are rendered directly rather than by evaluating a body.
    public var body: Never { fatalError("Primitive views do not have a body") }
}
