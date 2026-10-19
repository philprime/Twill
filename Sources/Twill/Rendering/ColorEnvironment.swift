/// Retain declarations until each node's lexical theme is known, so a nested
/// palette can re-resolve a semantic style inherited from outside its boundary.
struct ColorEnvironment {
    var theme = Theme()
    var foreground: (any Style)?
    var background: (any Style)?
}
