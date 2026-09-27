/// Read/write access to a value owned by another mounted view.
@MainActor
@propertyWrapper
public struct Binding<Value> {
    private let getValue: @MainActor () -> Value
    private let setValue: @MainActor (Value) -> Void

    public init(get: @escaping @MainActor () -> Value, set: @escaping @MainActor (Value) -> Void) {
        getValue = get
        setValue = set
    }

    public var wrappedValue: Value {
        get { getValue() }
        nonmutating set { setValue(newValue) }
    }

    public var projectedValue: Binding<Value> { self }
}
