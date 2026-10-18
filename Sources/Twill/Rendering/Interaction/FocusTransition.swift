/// The result of a focus decision, separated from the side effects needed to publish it.
///
/// Resolution, keyboard navigation, and branch restoration all use this same application
/// path. Ordered effects let each preserve its existing memory/reveal ordering without
/// independently invoking blur callbacks, synchronizing bindings, or requesting frames.
///
/// This is a synchronous value, not an event queue or persistent command. Its strong node
/// references must be discarded after application so removed views can be released. Mounted
/// memories remain weak. Regather a resolution request after any intervening input or tree update.
@MainActor
struct FocusTransition {
    /// Memory-only changes do not publish focus. A normal target change performs blur
    /// and binding synchronization. Reset invalidates the presentation marker after
    /// modal dismissal without treating shared modal binding writes as a new request
    /// to clear the enclosing scope's remembered target.
    enum Presentation {
        case unchanged
        case target(ViewRenderer?)
        case reset
    }

    /// Only focus-related mutations are expressible. Their order matters: a pane must
    /// remember its target and resume follow-focus before revealing that target. The
    /// renderer, not the selection policy, knows how these effects reach mounted storage.
    enum Effect {
        case remember(scope: ViewRenderer, target: ViewRenderer?)
        case activatePane(scope: ViewRenderer, pane: ViewRenderer?)
        case clearedBinding(scope: ViewRenderer, binding: ViewRenderer?)
        case followFocus(target: ViewRenderer?)
        case reveal(pane: ViewRenderer, target: ViewRenderer)
    }

    var presentation: Presentation = .unchanged
    var effects: [Effect] = []
    // Resolution during a frame must not enqueue another frame. Navigation explicitly
    // requests a redraw of cached descriptions without invalidating unrelated view bodies.
    var requestsPresentation = false

    var target: ViewRenderer? {
        if case .target(let target) = presentation { return target }
        return nil
    }
}
