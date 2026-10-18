/// Manual scrolling persists until navigation or selection explicitly requests reveal.
struct MountedScrollState {
    struct ListReveal: Equatable {
        let selection: AnyHashable?
        let bounds: CellRect?
        let viewport: CellSize
    }

    private(set) var offset = 0
    private(set) var followsFocus = true
    private(set) var contentHeight = 0
    var listReveal: ListReveal?

    mutating func updateContent(height: Int, viewportHeight: Int?) {
        contentHeight = height
        if let viewportHeight {
            offset = min(offset, max(0, height - viewportHeight))
        }
    }

    mutating func followFocus() {
        followsFocus = true
    }

    mutating func scroll(by distance: Int, viewportHeight: Int) -> Bool {
        let updated = min(max(0, offset + distance), max(0, contentHeight - viewportHeight))
        guard updated != offset else { return false }
        followsFocus = false
        offset = updated
        return true
    }

    mutating func scroll(to requested: Int, viewportHeight: Int) -> Bool {
        // Explicit positioning takes precedence over follow-focus even at the current offset.
        followsFocus = false
        let updated = min(max(0, requested), max(0, contentHeight - viewportHeight))
        guard updated != offset else { return false }
        offset = updated
        return true
    }

    mutating func reveal(_ rect: CellRect, viewport: CellSize) {
        if rect.row < offset {
            offset = rect.row
        } else if rect.row + rect.height > offset + viewport.height {
            offset = rect.row + rect.height - viewport.height
        }
        offset = min(max(0, offset), max(0, contentHeight - viewport.height))
    }
}
