/// Capabilities supplied for one synchronous node drawing operation.
///
/// Bounds and focus appearance are resolved by the mounted runtime. Direct focus is
/// distinct from inherited appearance: a tab bar must not highlight when its content
/// has focus, while a selected row may remain highlighted outside the active pane.
///
/// The child callback preserves tree traversal in its owner. It may retain mounted
/// descendants for this call, so neither this context nor its callback may be cached
/// in presentation data or used by deferred work. Terminal output stays with the host.
@MainActor
struct NodePresentationContext {
    let size: CellSize
    let isFocused: Bool
    let isDirectlyFocused: Bool
    // Control appearance can replace reverse video without suppressing caret ownership.
    var focusHighlight: Bool?
    let drawChildren: @MainActor (inout DrawingContext) -> Void
}
