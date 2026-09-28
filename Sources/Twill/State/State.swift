@MainActor
protocol StateLocation: AnyObject {
    var onChange: (() -> Void)? { get set }
}

@MainActor
protocol MountedStateProperty {
    var location: any StateLocation { get }
    func bind(to location: any StateLocation)
}

/// State belongs to the mounted view, not to later copies of its description.
@MainActor
@propertyWrapper
public struct State<Value> {
    @MainActor
    private final class Location: StateLocation {
        var value: Value
        var onChange: (() -> Void)?

        init(_ value: Value) {
            self.value = value
        }
    }

    /// View copies keep this handle; mounting redirects it to the node's retained location.
    @MainActor
    private final class Handle {
        var location: Location

        init(_ value: Value) {
            location = Location(value)
        }
    }

    private let handle: Handle

    public init(wrappedValue: Value) {
        handle = Handle(wrappedValue)
    }

    public var wrappedValue: Value {
        get { handle.location.value }
        nonmutating set {
            handle.location.value = newValue
            handle.location.onChange?()
        }
    }

    public var projectedValue: Binding<Value> {
        // The binding writes through this handle, which follows the owner's
        // mounted location when parent descriptions are rebuilt.
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}

extension State: MountedStateProperty {
    var location: any StateLocation { handle.location }

    func bind(to location: any StateLocation) {
        // Reconciliation matches concrete view types, so a property cannot change
        // its value type while keeping the same mounted identity.
        guard let typedLocation = location as? Location else {
            preconditionFailure("Mounted state property changed type")
        }
        handle.location = typedLocation
    }
}
