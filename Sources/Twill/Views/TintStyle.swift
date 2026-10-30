/// The nearest control tint, falling back to the inherited primary foreground color.
public struct TintStyle: Style {
    /// Creates a style that follows the nearest tint override.
    public init() {}

    /// Resolves at the presentation node, so nested tint overrides affect inherited declarations.
    public func resolve(in context: StyleContext) -> ResolvedStyle {
        ResolvedStyle(color: context.tint ?? context.foreground.color)
    }
}

extension Style where Self == TintStyle {
    /// A foreground or background style that follows the nearest control tint.
    public static var tint: Self { TintStyle() }
}
