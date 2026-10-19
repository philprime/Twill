/// A labeled action in a menu. Disabled items remain visible but cannot receive focus or activate.
@MainActor
public struct MenuItem {
    /// The label displayed for the action.
    public let title: String
    /// Alternative shortcuts while the menu is open. Enter and Escape retain
    /// their focused activation and dismissal behavior.
    public let shortcuts: [KeyboardShortcut]
    /// The semantic role of the action.
    public let role: ButtonRole?
    /// Whether the action can be selected and invoked.
    public let isEnabled: Bool
    let action: @MainActor () -> Void

    /// Creates a menu action with shortcut alternatives and availability.
    public init(
        _ title: String, shortcuts: [KeyboardShortcut] = [], isEnabled: Bool = true, role: ButtonRole? = nil,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.shortcuts = shortcuts
        self.role = role
        self.isEnabled = isEnabled
        self.action = action
    }

    /// Shares a command's title, availability, role, shortcut alternatives, and action.
    public init<ID>(_ command: Command<ID>) {
        self.init(
            command.title, shortcuts: command.shortcuts, isEnabled: command.isEnabled,
            role: command.role, action: command.perform)
    }
}
