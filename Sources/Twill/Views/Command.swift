/// A reusable description of an action and its current availability.
/// Identity is application metadata, not implicit mounted view identity or a global registration.
public struct Command<ID: Hashable>: Identifiable {
    /// The application's stable identifier for this action.
    public let id: ID
    /// The current title shared by controls and help text.
    public let title: String
    /// Whether the action is currently available.
    public let isEnabled: Bool
    /// The semantic role used by controls and modal action policy.
    public let role: ButtonRole?
    /// Alternative terminal shortcuts and their display hints.
    public let shortcuts: [KeyboardShortcut]
    private let action: @MainActor () -> Void

    /// Creates a command snapshot. Derive it from mounted state in a view body
    /// to keep controls and hints synchronized as availability or metadata changes.
    public init(
        _ id: ID, title: String, isEnabled: Bool = true, role: ButtonRole? = nil,
        shortcuts: [KeyboardShortcut] = [], action: @escaping @MainActor () -> Void
    ) {
        self.id = id
        self.title = title
        self.isEnabled = isEnabled
        self.role = role
        self.shortcuts = shortcuts
        self.action = action
    }

    /// Performs the action only when this command snapshot is available.
    @MainActor
    public func perform() {
        guard isEnabled else { return }
        action()
    }
}
