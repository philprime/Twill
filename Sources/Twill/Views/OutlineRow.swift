/// Flattening keeps row identity independent of its depth and visible position.
struct OutlineRow<Element, ID: Hashable> {
    let id: ID
    let element: Element
    let parentID: ID?
    let depth: Int
    let isBranch: Bool
    let isExpanded: Bool

    var marker: String { isBranch ? (isExpanded ? "▾" : "▸") : " " }
}
