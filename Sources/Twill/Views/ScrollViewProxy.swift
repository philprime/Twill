/// Positions a measured keyed target inside its nearest scroll viewport in this reader.
@MainActor
public final class ScrollViewProxy {
    /// How a target is positioned relative to its viewport.
    public enum Anchor {
        /// Aligns the target's top edge with the viewport's top edge.
        case top
        /// Aligns the target's bottom edge with the viewport's bottom edge.
        case bottom
        /// Centers the target, leaving any extra terminal row below it.
        case center
        /// Moves only enough to reveal the target, or to lie inside an oversized target.
        case nearest

        func offset(for bounds: CellRect, viewportHeight: Int, current: Int) -> Int {
            let bottom = bounds.row + bounds.height - viewportHeight
            switch self {
            case .top: return bounds.row
            case .bottom: return bottom
            case .center: return bounds.row + (bounds.height - viewportHeight) / 2
            case .nearest: return min(max(current, min(bounds.row, bottom)), max(bounds.row, bottom))
            }
        }
    }

    weak var renderer: ViewRenderer?

    /// Scrolls to a ForEach key or explicit `.id`, without moving keyboard focus.
    /// Lookup follows active reader content but does not enter nested readers.
    /// Missing, removed, or unmeasured targets are ignored.
    public func scrollTo<ID: Hashable>(_ id: ID, anchor: Anchor = .top) {
        guard let target = renderer?.scrollTarget(for: AnyHashable(id)) else { return }
        let viewport = target.viewport
        let requested = anchor.offset(
            for: target.bounds, viewportHeight: viewport.layoutState.size.height,
            current: viewport.scrollState.offset)
        // Explicit positioning takes precedence over follow-focus even when already visible.
        guard viewport.scrollState.scroll(to: requested, viewportHeight: viewport.layoutState.size.height) else {
            return
        }
        viewport.requestFocusPresentation()
    }
}
