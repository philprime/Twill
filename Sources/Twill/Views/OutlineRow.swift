/// Flattening keeps row identity independent of its depth and visible position.
struct OutlineRow<Element, ID: Hashable> {
    let id: ID
    let element: Element
    let parentID: ID?
    let depth: Int
    let isBranch: Bool
    let isExpanded: Bool

    var marker: String { isBranch ? (isExpanded ? "▾" : "▸") : " " }

    static func visibleRows<Data: RandomAccessCollection>(
        in data: Data, id: KeyPath<Element, ID>, children: KeyPath<Element, Data?>, expandedIDs: Set<ID>
    ) -> [Self] where Data.Element == Element {
        var rows: [Self] = []
        func append(_ data: Data, parentID: ID?, depth: Int) {
            for element in data {
                let rowID = element[keyPath: id]
                let descendants = element[keyPath: children]
                let isExpanded = descendants != nil && expandedIDs.contains(rowID)
                rows.append(
                    Self(
                        id: rowID, element: element, parentID: parentID, depth: depth,
                        isBranch: descendants != nil, isExpanded: isExpanded))
                if isExpanded, let descendants { append(descendants, parentID: rowID, depth: depth + 1) }
            }
        }
        append(data, parentID: nil, depth: 0)
        return rows
    }
}
