/// A labeled action in a menu. Disabled items remain visible but cannot receive focus or activate.
@MainActor
public struct MenuItem {
    public let title: String
    public let shortcut: MenuShortcut?
    public let isEnabled: Bool
    let action: @MainActor () -> Void

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
