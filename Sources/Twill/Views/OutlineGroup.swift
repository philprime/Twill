/// A single-selection, scrolling hierarchy with externally owned expansion state.
/// Up/Down and Home/End select visible rows. Right expands a branch or selects
/// its first child, while Left collapses a branch or selects its parent. Enter
/// activates the effective element, or invokes the nearest `.onSubmit` action
/// when no activation callback is supplied. Selection remains visible without focus.
/// IDs must be stable and unique across the entire hierarchy. A nil children
/// collection identifies a leaf, while an empty collection is an expandable branch.
/// The selection policy resolves nil, hidden, and missing IDs without changing
/// the binding. Its default is the first visible row. Collapsed rows are unmounted, so keep values
/// that must survive collapse in an ancestor.
public struct OutlineGroup<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let children: KeyPath<Data.Element, Data?>
    private let selection: Binding<ID?>
    private let expandedIDs: Binding<Set<ID>>
    private let selectionPolicy: SelectionPolicy
    private let rowContent: @MainActor (Data.Element) -> RowContent
    private var activation: (@MainActor (Data.Element) -> Void)?

    /// Creates a hierarchy with explicit stable identities, child collections, and bound selection and expansion.
    /// IDs must be unique throughout the hierarchy; nil children mark a leaf.
    public init(
        _ data: Data, id: KeyPath<Data.Element, ID>, children: KeyPath<Data.Element, Data?>,
        selection: Binding<ID?>, expandedIDs: Binding<Set<ID>>, selectionPolicy: SelectionPolicy = .firstVisible,
        @ViewBuilder rowContent: @escaping @MainActor (Data.Element) -> RowContent
    ) {
        self.data = data
        self.id = id
        self.children = children
        self.selection = selection
        self.expandedIDs = expandedIDs
        self.selectionPolicy = selectionPolicy
        self.rowContent = rowContent
    }

    /// Activates the effective visible original element instead of `.onSubmit`.
    /// Hidden or missing IDs follow the configured selection policy.
    public func onActivate(_ action: @escaping @MainActor (Data.Element) -> Void) -> Self {
        var view = self
        view.activation = action
        return view
    }

    /// The visible hierarchy flattened into indented selectable rows with expansion-key handling.
    public var body: some View {
        let rows = visibleRows
        var list = List(rows, id: \.id, selection: selection, selectionPolicy: selectionPolicy) { row in
            HStack(spacing: 1) {
                Text(row.marker)
                rowContent(row.element)
            }
            .padding(.leading, row.depth * 2)
        }
        if let activation { list = list.onActivate { activation($0.element) } }
        return list.onKeyPress { handle($0, rows: rows) }
    }

    private var visibleRows: [OutlineRow<Data.Element, ID>] {
        OutlineRow.visibleRows(in: data, id: id, children: children, expandedIDs: expandedIDs.wrappedValue)
    }

    private func handle(_ key: KeyEvent, rows: [OutlineRow<Data.Element, ID>]) -> KeyPressResult {
        guard key == .arrowLeft || key == .arrowRight else { return .ignored }
        guard let index = selectionPolicy.index(in: rows, selection: selection.wrappedValue, id: { $0.id })
        else { return .handled }
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
    /// Creates a hierarchy using each element's `id`, with externally owned selection and expansion state.
    public init(
        _ data: Data, children: KeyPath<Data.Element, Data?>,
        selection: Binding<ID?>, expandedIDs: Binding<Set<ID>>, selectionPolicy: SelectionPolicy = .firstVisible,
        @ViewBuilder rowContent: @escaping @MainActor (Data.Element) -> RowContent
    ) {
        self.init(
            data, id: \.id, children: children, selection: selection, expandedIDs: expandedIDs,
            selectionPolicy: selectionPolicy, rowContent: rowContent)
    }
}
