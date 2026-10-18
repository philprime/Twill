/// A read-only snapshot of the facts needed to resolve one mounted scope's focus.
///
/// The renderer gathers these facts because it owns tree traversal and binding access.
/// The coordinator receives candidates rather than a tree to search, keeping target
/// selection testable without also running blur callbacks or rewriting bindings.
/// Requests are gathered and resolved synchronously on the UI actor, never queued.
@MainActor
struct FocusRequest {
    /// Automatic focus may prefer a cancellation action, but a valid remembered
    /// target always wins. Explicit requests instead use their requested subtree's order.
    struct Candidates {
        let nodes: [ViewRenderer]
        let remembered: ViewRenderer?
        let preferred: ViewRenderer?
    }

    /// Gathering stops at the first applicable reason: an explicit request, a cleared
    /// binding, retained screen focus, then automatic pane/control fallback. Each
    /// reason carries only the candidates and memories that its decision needs.
    enum Reason {
        case explicit(candidates: [ViewRenderer], remembered: ViewRenderer?, pane: ViewRenderer?)
        case cleared(ViewRenderer)
        case remembered(ViewRenderer)
        case automatic(candidates: Candidates, pane: ViewRenderer?, updatePane: Bool)
    }

    // Node references identify where effects belong. The coordinator uses their identity,
    // not their mutable storage, and the request cannot outlive this resolution pass.
    let scope: ViewRenderer
    let presented: ViewRenderer?
    let reason: Reason
}
