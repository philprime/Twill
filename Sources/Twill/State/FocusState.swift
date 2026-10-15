/// Mounted focus state for programmatically selecting a control or a container.
@MainActor
@propertyWrapper
public struct FocusState<Value: Hashable> {
    private let state: State<Value>

    public init(wrappedValue: Value) {
        state = State(wrappedValue: wrappedValue)
    }

    public init() where Value == Bool {
        self.init(wrappedValue: false)
    }

    public init<Wrapped>() where Value == Wrapped? {
        self.init(wrappedValue: nil)
    }

    public var wrappedValue: Value {
        get { state.wrappedValue }
        nonmutating set { state.wrappedValue = newValue }
    }

    public var projectedValue: Binding {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }

    @MainActor
    public struct Binding {
        let get: () -> Value
        let set: (Value) -> Void

        init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
            self.get = get
            self.set = set
        }

        public var wrappedValue: Value {
            get { get() }
            nonmutating set { set(newValue) }
        }
    }
}

extension FocusState: MountedStateProperty {
    var location: any StateLocation { state.location }

    func bind(to location: any StateLocation) {
        state.bind(to: location)
    }
}
