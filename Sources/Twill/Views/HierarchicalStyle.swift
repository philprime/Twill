/// Foreground prominence relative to the containing primary style.
public struct HierarchicalStyle: Style {
    fileprivate enum Level {
        case primary
        case secondary
    }

    private let level: Level

    fileprivate init(level: Level) { self.level = level }

    /// Secondary preserves the foreground hue. Terminal dim is an approximation
    /// of reduced prominence whose appearance depends on the terminal and font.
    public func resolve(in context: StyleContext) -> ResolvedStyle {
        switch level {
        case .primary: context.foreground
        case .secondary:
            ResolvedStyle(color: context.foreground.color, attributes: context.foreground.attributes.union(.dim))
        }
    }
}

extension Style where Self == HierarchicalStyle {
    /// The inherited primary foreground style.
    public static var primary: Self { Self(level: .primary) }
    /// Reduced foreground prominence without replacing its hue.
    public static var secondary: Self { Self(level: .secondary) }
}
