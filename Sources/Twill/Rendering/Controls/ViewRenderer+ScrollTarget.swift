/// Scroll targeting uses reader-local active geometry, not retained global identity lookup.
extension ViewRenderer {
    func scrollTarget(for id: AnyHashable) -> (viewport: ViewRenderer, bounds: CellRect)? {
        for child in interactionChildren {
            if let target = child.findScrollTarget(for: id, viewport: nil) { return target }
        }
        return nil
    }

    private func findScrollTarget(for id: AnyHashable, viewport inherited: ViewRenderer?) -> (
        viewport: ViewRenderer, bounds: CellRect
    )? {
        // A nested reader owns a separate ID namespace even inside an outer viewport.
        if case .scrollReader = description { return nil }
        let viewport: ViewRenderer?
        if case .scroll = description { viewport = self } else { viewport = inherited }
        let children = interactionChildren
        if let viewport, let candidate = childStorage.keyedNode(for: id) {
            if children.contains(where: { $0 === candidate }) {
                let bounds = viewport.bounds(of: candidate, column: 0, row: 0, includingAllLayoutItems: true)
                if let bounds { return (viewport, bounds) }
            }
        }
        for child in children {
            if let target = child.findScrollTarget(for: id, viewport: viewport) { return target }
        }
        return nil
    }
}
