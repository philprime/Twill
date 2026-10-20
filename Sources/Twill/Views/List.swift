/// A single-selection, vertically scrolling collection of keyed rows.
///
/// The list is one control-level Tab stop. Up/Down and Home/End change selection,
/// and Enter invokes the nearest `.onSubmit` action. Selection stays visible
/// when another control has focus. Row content describes presentation, not
/// independently focusable controls.
public struct List<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let selection: Binding<ID?>
    private let selectionPolicy: SelectionPolicy
    private let rowContent: @MainActor (Data.Element) -> RowContent

    /// Creates a list with stable, unique row IDs and externally owned selection.
    /// The policy resolves nil or missing IDs without changing the binding.
    /// By default the first visible row is selected; allow-empty retains no selection.
    public init(
        _ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<ID?>,
        selectionPolicy: SelectionPolicy = .firstVisible,
        @ViewBuilder rowContent: @escaping @MainActor (Data.Element) -> RowContent
    ) {
        self.data = data
        self.id = id
        self.selection = selection
        self.selectionPolicy = selectionPolicy
        self.rowContent = rowContent
    }

    private var selectedIndex: Data.Index? {
        selectionPolicy.index(in: data, selection: selection.wrappedValue, id: { $0[keyPath: id] })
    }

    private func handle(_ key: KeyEvent) -> KeyPressResult {
        guard [.arrowDown, .arrowUp, .home, .end, .enter].contains(key) else { return .ignored }
        guard
            let index = selectionPolicy.navigationIndex(
                for: key, in: data, selection: selection.wrappedValue, id: { $0[keyPath: id] })
        else { return .handled }
        selection.wrappedValue = data[index][keyPath: id]
        // Submission routes through the existing enclosing action after selecting
        // the effective row. Without an effective row, Enter is consumed without submitting.
        return key == .enter ? .ignored : .handled
    }
}

extension List where Data.Element: Identifiable, ID == Data.Element.ID {
    /// Creates a selectable list using each element's stable, unique `id` as its row identity.
    public init(
        _ data: Data, selection: Binding<ID?>, selectionPolicy: SelectionPolicy = .firstVisible,
        @ViewBuilder rowContent: @escaping @MainActor (Data.Element) -> RowContent
    ) {
        self.init(data, id: \.id, selection: selection, selectionPolicy: selectionPolicy, rowContent: rowContent)
    }
}

extension List: PrimitiveView {
    func makeDescription() -> ViewDescription {
        let selectedID = selectedIndex.map { data[$0][keyPath: id] }
        return .pane(
            ScrollView {
                ListSelectionContent(
                    content: VStack(alignment: .leading, spacing: 0) {
                        ForEach(data, id: id) { element in
                            ListRow(content: rowContent(element), isSelected: element[keyPath: id] == selectedID)
                        }
                    },
                    selection: selectedID.map(AnyHashable.init), handle: handle)
            })
    }
}

struct ListSelectionContent<Content: View>: View, PrimitiveView {
    typealias Body = Never
    let content: Content
    let selection: AnyHashable?
    let handle: @MainActor (KeyEvent) -> KeyPressResult

    func makeDescription() -> ViewDescription { .listSelection(content, selection, handle) }
}

struct ListRow<Content: View>: View, PrimitiveView {
    typealias Body = Never
    let content: Content
    let isSelected: Bool

    func makeDescription() -> ViewDescription { .listRow(content, isSelected: isSelected) }
}
