/// A color role resolved against the nearest theme during presentation.
public enum SemanticColor: Style {
    /// Normal text content.
    case foreground
    /// Normal surface content.
    case background
    /// Highlighted actions and emphasis.
    case accent
    /// Secondary content.
    case muted
    /// Validation feedback and destructive actions.
    case validation

    /// Returns the concrete palette entry, including an explicit terminal default.
    public func resolve(in theme: Theme) -> Color? {
        switch self {
        case .foreground: theme.foreground
        case .background: theme.background
        case .accent: theme.accent
        case .muted: theme.muted
        case .validation: theme.validation
        }
    }
}
