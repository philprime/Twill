/// Mounted focus state for programmatically selecting a control or a container.
@MainActor
@propertyWrapper
public struct FocusState<Value: Hashable> {
    private let state: State<Value>

    /// Creates focus state with the supplied initial selection.
    public init(wrappedValue: Value) {
        state = State(wrappedValue: wrappedValue)
    }

    /// Creates Boolean focus state initially set to false.
    public init() where Value == Bool {
        self.init(wrappedValue: false)
    }

    /// Creates optional focus state with no initial selection.
    public init<Wrapped>() where Value == Wrapped? {
        self.init(wrappedValue: nil)
    }

    /// The mounted focus selection used for programmatic focus changes.
    public var wrappedValue: Value {
        get { state.wrappedValue }
        nonmutating set { state.wrappedValue = newValue }
    }

    /// A binding that connects a control or container to this focus state.
    public var projectedValue: Binding {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }

    /// Read/write access to the mounted focus selection for a focus attachment.
    @MainActor
    public struct Binding {
        let get: () -> Value
        let set: (Value) -> Void

        init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
            self.get = get
            self.set = set
        }

        /// The focus selection read or written through this attachment.
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
