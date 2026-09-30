/// A view that starts an asynchronous action when it enters the mounted hierarchy.
public struct TaskView<Content: View>: View {
    public typealias Body = Never
    private let content: Content
    private let priority: TaskPriority
    private let action: @MainActor @Sendable () async -> Void

    init(content: Content, priority: TaskPriority, action: @escaping @MainActor @Sendable () async -> Void) {
        self.content = content
        self.priority = priority
        self.action = action
    }
}

extension View {
    /// Adds an asynchronous task to perform when this view is mounted.
    ///
    /// Use this modifier to load data or perform other asynchronous work whose lifetime
    /// matches the view's mounted identity. The task begins after the view first mounts.
    /// Updating the view while it retains the same identity does not restart the task.
    /// If the view is removed, replaced, or the application stops, the task is cancelled.
    /// Cancellation is cooperative: the action must check for cancellation or call a
    /// cancellation-aware operation to stop promptly.
    ///
    /// Update mounted state from the action to show its result:
    ///
    /// ```swift
    /// @State private var title = "Loading"
    ///
    /// var body: some View {
    ///     Text(title)
    ///         .task {
    ///             title = await loadTitle()
    ///         }
    /// }
    /// ```
    ///
    /// The action does not throw. Handle errors inside the closure, for example with
    /// `do` and `catch`, and update the view's state to present an error.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task. Defaults to `.userInitiated`.
    ///   - action: The asynchronous operation to perform on the UI actor.
    /// - Returns: A view that starts the action when mounted.
    public func task(
        priority: TaskPriority = .userInitiated,
        _ action: @escaping @MainActor @Sendable () async -> Void
    ) -> TaskView<Self> {
        TaskView(content: self, priority: priority, action: action)
    }
}

extension TaskView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .task(content, priority: priority, action: action)
    }
}
