/// Owns asynchronous work that restarts only when its equatable task identity changes.
public struct KeyedTaskView<Content: View, ID: Equatable>: View {
    /// Primitive content rendered directly by the runtime.
    public typealias Body = Never
    @State private var identity: TaskIdentity<ID>
    private let content: Content
    private let id: ID
    private let priority: TaskPriority
    private let action: @MainActor @Sendable () async -> Void

    init(content: Content, id: ID, priority: TaskPriority, action: @escaping @MainActor @Sendable () async -> Void) {
        self._identity = State(wrappedValue: TaskIdentity<ID>())
        self.content = content
        self.id = id
        self.priority = priority
        self.action = action
    }
}

extension View {
    /// Starts work on mount and cancels/joins it before a changed ID starts replacement work.
    /// Equal IDs preserve running or completed work, including its original action and priority.
    /// Cancellation is cooperative. Handle errors inside the nonthrowing action.
    public func task<ID: Equatable>(
        id: ID, priority: TaskPriority = .userInitiated,
        _ action: @escaping @MainActor @Sendable () async -> Void
    ) -> KeyedTaskView<Self, ID> {
        KeyedTaskView(content: self, id: id, priority: priority, action: action)
    }
}

extension KeyedTaskView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .task(content, priority: priority, restart: identity.update(id), action: action)
    }
}
