/// Read/write access to a value owned by another mounted view.
@MainActor
@propertyWrapper
@dynamicMemberLookup
public struct Binding<Value> {
    private let getValue: @MainActor () -> Value
    private let setValue: @MainActor (Value) -> Void

    /// Creates access to an externally owned value using the supplied getter and setter.
    public init(get: @escaping @MainActor () -> Value, set: @escaping @MainActor (Value) -> Void) {
        getValue = get
        setValue = set
    }

    /// Creates a binding from its projection, enabling `$value` closure parameters.
    public init(projectedValue: Binding<Value>) {
        self = projectedValue
    }

    /// Reads or writes the value through the supplied accessors.
    public var wrappedValue: Value {
        get { getValue() }
        nonmutating set { setValue(newValue) }
    }

    /// The binding itself, available through property-wrapper projection.
    public var projectedValue: Binding<Value> { self }

    /// Creates a binding that always reads the supplied value and ignores writes.
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(get: { value }, set: { _ in })
    }

    /// Projects a writable property, reading the latest owner value on every access.
    public subscript<Member>(dynamicMember keyPath: WritableKeyPath<Value, Member>) -> Binding<Member> {
        Binding<Member>(
            get: { wrappedValue[keyPath: keyPath] },
            set: { newValue in
                var value = wrappedValue
                value[keyPath: keyPath] = newValue
                wrappedValue = value
            })
    }
}
