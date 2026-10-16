/// A single-selection, scrolling hierarchy with externally owned expansion state.
/// Up/Down and Home/End select visible rows. Right expands a branch or selects
/// its first child, while Left collapses a branch or selects its parent. Enter
/// invokes the nearest `.onSubmit` action. Selection remains visible without focus.
/// IDs must be stable and unique across the entire hierarchy. A nil children
/// collection identifies a leaf, while an empty collection is an expandable branch.
/// Hidden or missing selections fall back visually to the first visible row
/// without changing the binding. Collapsed rows are unmounted, so keep values
/// that must survive collapse in an ancestor.
public struct OutlineGroup<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let children: KeyPath<Data.Element, Data?>
    private let selection: Binding<ID?>
    private let expandedIDs: Binding<Set<ID>>
    private let rowContent: @MainActor (Data.Element) -> RowContent

    public init(
        _ data: Data, id: KeyPath<Data.Element, ID>, children: KeyPath<Data.Element, Data?>,
        selection: Binding<ID?>, expandedIDs: Binding<Set<ID>>,
        @ViewBuilder rowContent: @escaping @MainActor (Data.Element) -> RowContent
    ) {
        self.data = data
        self.id = id
        self.children = children
        self.selection = selection
        self.expandedIDs = expandedIDs
        self.rowContent = rowContent
    }

    public var body: some View {
        let rows = visibleRows
        return List(rows, id: \.id, selection: selection) { row in
            HStack(spacing: 1) {
                Text(row.marker)
                rowContent(row.element)
            }
            .padding(.leading, row.depth * 2)
        }
        .onKeyPress { handle($0, rows: rows) }
    }

    private var visibleRows: [OutlineRow<Data.Element, ID>] {
        var rows: [OutlineRow<Data.Element, ID>] = []
        let expanded = expandedIDs.wrappedValue
        func append(_ data: Data, parentID: ID?, depth: Int) {
            for element in data {
                let rowID = element[keyPath: id]
                let descendants = element[keyPath: children]
                let isExpanded = descendants != nil && expanded.contains(rowID)
                rows.append(
                    OutlineRow(
                        id: rowID, element: element, parentID: parentID, depth: depth,
                        isBranch: descendants != nil, isExpanded: isExpanded))
                if isExpanded, let descendants {
                    append(descendants, parentID: rowID, depth: depth + 1)
                }
            }
        }
        append(data, parentID: nil, depth: 0)
        return rows
    }

    private func handle(_ key: KeyEvent, rows: [OutlineRow<Data.Element, ID>]) -> KeyPressResult {
        guard key == .arrowLeft || key == .arrowRight else { return .ignored }
        guard !rows.isEmpty else { return .handled }
        let index = rows.firstIndex { $0.id == selection.wrappedValue } ?? rows.startIndex
        let row = rows[index]
        var selectedID = row.id
        if key == .arrowLeft {
            if row.isExpanded {
                expandedIDs.wrappedValue.remove(row.id)
            } else if let parentID = row.parentID {
                selectedID = parentID
            }
        } else if row.isBranch {
            if !row.isExpanded {
                expandedIDs.wrappedValue.insert(row.id)
            } else {
                let next = rows.index(after: index)
                if next != rows.endIndex, rows[next].parentID == row.id { selectedID = rows[next].id }
            }
        }
        selection.wrappedValue = selectedID
        return .handled
    }
}

extension OutlineGroup where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(
        _ data: Data, children: KeyPath<Data.Element, Data?>,
        selection: Binding<ID?>, expandedIDs: Binding<Set<ID>>,
        @ViewBuilder rowContent: @escaping @MainActor (Data.Element) -> RowContent
    ) {
        self.init(
            data, id: \.id, children: children, selection: selection, expandedIDs: expandedIDs, rowContent: rowContent)
    }
}
