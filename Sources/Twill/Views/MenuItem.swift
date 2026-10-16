/// A labeled action in a menu. Disabled items remain visible but cannot receive focus or activate.
@MainActor
public struct MenuItem {
    /// The label displayed for the action.
    public let title: String
    /// The optional key event and display hint for invoking the action.
    public let shortcut: MenuShortcut?
    /// Whether the action can be selected and invoked.
    public let isEnabled: Bool
    let action: @MainActor () -> Void

    /// Creates a menu action with an optional shortcut and enabled state.
    public init(
        _ title: String, shortcut: MenuShortcut? = nil, isEnabled: Bool = true,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.shortcut = shortcut
        self.isEnabled = isEnabled
        self.action = action
    }
}
