/// Read/write access to a value owned by another mounted view.
@MainActor
@propertyWrapper
public struct Binding<Value> {
    private let getValue: @MainActor () -> Value
    private let setValue: @MainActor (Value) -> Void

    /// Creates access to an externally owned value using the supplied getter and setter.
    public init(get: @escaping @MainActor () -> Value, set: @escaping @MainActor (Value) -> Void) {
        getValue = get
        setValue = set
    }

    /// Reads or writes the value through the supplied accessors.
    public var wrappedValue: Value {
        get { getValue() }
        nonmutating set { setValue(newValue) }
    }

    /// The binding itself, available through property-wrapper projection.
    public var projectedValue: Binding<Value> { self }
}
