/// Keep declarations until the node's tint is known. Hierarchical styles refer to
/// the primary declaration rather than recursively modifying their own result.
struct StyleEnvironment {
    var tint: Color?
    var background: (any Style)?
    // Attribute modifiers nearer than the active style can clear its contributions.
    var attributeOverrides: TextAttributes = []
    private var foreground: (any Style)?
    private var primary: (any Style)?
    private var inheritedPrimary = ResolvedStyle(color: nil)

    var context: StyleContext {
        let inherited = StyleContext(foreground: inheritedPrimary, tint: tint)
        return StyleContext(foreground: primary?.resolve(in: inherited) ?? inheritedPrimary, tint: tint)
    }

    var hasForegroundStyle: Bool { primary != nil || foreground != nil }

    var resolvedForeground: ResolvedStyle {
        foreground?.resolve(in: context) ?? context.foreground
    }

    var resolvedBackground: ResolvedStyle? { background?.resolve(in: context) }

    mutating func applyForeground(_ style: any Style) {
        if style is HierarchicalStyle {
            attributeOverrides.remove(.dim)
            foreground = style
        } else {
            attributeOverrides = []
            inheritedPrimary = context.foreground
            primary = style
            foreground = nil
        }
    }
}
