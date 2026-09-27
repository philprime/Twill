@MainActor
protocol StateLocation: AnyObject {
    var onChange: (() -> Void)? { get set }
}

@MainActor
protocol MountedStateProperty {
    var location: any StateLocation { get }
    func bind(to location: any StateLocation)
}

@MainActor
private final class StateValue<Value>: StateLocation {
    var value: Value
    var onChange: (() -> Void)?

    init(_ value: Value) {
        self.value = value
    }
}

/// View copies keep this handle; mounting redirects it to the node's retained location.
@MainActor
private final class StateHandle<Value> {
    var location: StateValue<Value>

    init(_ value: Value) {
        location = StateValue(value)
    }
}

/// State belongs to the mounted view, not to later copies of its description.
@MainActor
@propertyWrapper
public struct State<Value> {
    private let handle: StateHandle<Value>

    public init(wrappedValue: Value) {
        handle = StateHandle(wrappedValue)
    }

    public var wrappedValue: Value {
        get { handle.location.value }
        nonmutating set {
            handle.location.value = newValue
            handle.location.onChange?()
        }
    }
}

extension State: MountedStateProperty {
    var location: any StateLocation { handle.location }

    func bind(to location: any StateLocation) {
        // Reconciliation matches concrete view types, so a property cannot change
        // its value type while keeping the same mounted identity.
        guard let typedLocation = location as? StateValue<Value> else {
            preconditionFailure("Mounted state property changed type")
        }
        handle.location = typedLocation
    }
}
