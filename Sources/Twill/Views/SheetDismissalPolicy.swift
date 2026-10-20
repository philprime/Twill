/// Whether an ordinary sheet handles Escape after its content declines the key.
public enum SheetDismissalPolicy: Equatable, Sendable {
    /// Unhandled Escape dismisses the sheet without reaching underlying content.
    case escape
    /// Only caller actions and binding changes dismiss the sheet.
    case manual
}
