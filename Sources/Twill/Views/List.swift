/// A single-selection, vertically scrolling collection of keyed rows.
///
/// The list is one keyboard pane. Up/Down and Home/End change selection,
/// and Enter invokes the nearest `.onSubmit` action. Selection stays visible
/// when another pane is active. Row content describes presentation, not
/// independently focusable controls.
public struct List<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    public typealias Body = Never
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let selection: Binding<ID?>
    private let rowContent: @MainActor (Data.Element) -> RowContent

    /// Creates a list with stable, unique row IDs and externally owned selection.
    /// A missing ID displays the first row as selected without changing the binding.
    public init(
        _ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<ID?>,
        @ViewBuilder rowContent: @escaping @MainActor (Data.Element) -> RowContent
    ) {
        self.data = data
        self.id = id
        self.selection = selection
        self.rowContent = rowContent
    }

    private var selectedIndex: Data.Index? {
        data.firstIndex { $0[keyPath: id] == selection.wrappedValue } ?? (data.isEmpty ? nil : data.startIndex)
    }

    private func handle(_ key: KeyEvent) -> KeyPressResult {
        guard [.arrowDown, .arrowUp, .home, .end, .enter].contains(key) else { return .ignored }
        guard var index = selectedIndex else { return .handled }
        switch key {
        case .arrowDown:
            let next = data.index(after: index)
            if next != data.endIndex { index = next }
        case .arrowUp:
            if index != data.startIndex { index = data.index(before: index) }
        case .home: index = data.startIndex
        case .end: index = data.index(before: data.endIndex)
        default: break
        }
        selection.wrappedValue = data[index][keyPath: id]
        // Submission routes through the existing enclosing action after selecting
        // the effective row. An empty list consumes Enter without submitting.
        return key == .enter ? .ignored : .handled
    }
}

extension List where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(
        _ data: Data, selection: Binding<ID?>,
        @ViewBuilder rowContent: @escaping @MainActor (Data.Element) -> RowContent
    ) {
        self.init(data, id: \.id, selection: selection, rowContent: rowContent)
    }
}

extension List: PrimitiveView {
    func makeDescription() -> ViewDescription {
        let selectedID = selectedIndex.map { data[$0][keyPath: id] }
        return .scroll(
            ListSelectionContent(
                content: VStack(alignment: .leading, spacing: 0) {
                    ForEach(data, id: id) { element in
                        ListRow(content: rowContent(element), isSelected: element[keyPath: id] == selectedID)
                    }
                },
                selection: selectedID.map(AnyHashable.init), handle: handle))
    }
}

private struct ListSelectionContent<Content: View>: View, PrimitiveView {
    typealias Body = Never
    let content: Content
    let selection: AnyHashable?
    let handle: @MainActor (KeyEvent) -> KeyPressResult

    func makeDescription() -> ViewDescription { .listSelection(content, selection, handle) }
}

private struct ListRow<Content: View>: View, PrimitiveView {
    typealias Body = Never
    let content: Content
    let isSelected: Bool

    func makeDescription() -> ViewDescription { .listRow(content, isSelected: isSelected) }
}
