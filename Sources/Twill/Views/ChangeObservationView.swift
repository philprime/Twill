/// Observes equatable values at mounted update boundaries rather than during body evaluation.
public struct ChangeObservationView<Content: View, Value: Equatable>: View {
    /// Primitive content rendered directly by the runtime.
    public typealias Body = Never
    // The mounted State location owns this typed cache without invalidating on bookkeeping writes.
    @State private var observer: ValueChangeObserver<Value>
    private let content: Content
    private let value: Value
    private let initial: Bool
    private let action: @MainActor (Value, Value) -> Void

    init(content: Content, value: Value, initial: Bool, action: @escaping @MainActor (Value, Value) -> Void) {
        self._observer = State(wrappedValue: ValueChangeObserver<Value>())
        self.content = content
        self.value = value
        self.initial = initial
        self.action = action
    }
}

extension View {
    /// Delivers old/new values after reconciliation, coalescing equal and intermediate updates.
    /// Initial delivery is opt-in and supplies current/current on the first eligible pass.
    public func onChange<Value: Equatable>(
        of value: Value, initial: Bool = false, _ action: @escaping @MainActor (Value, Value) -> Void
    ) -> ChangeObservationView<Self, Value> {
        ChangeObservationView(content: self, value: value, initial: initial, action: action)
    }
}

extension ChangeObservationView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        observer.prepare(value: value, initial: initial, action: action)
        return .changeObservation(content, observer)
    }
}
