import Foundation

/// A single-selection scrolling table with one control-level Tab stop.
/// Sortable headers update the bound comparators; the caller sorts the data.
/// Up from the first row reaches the headers. Left/Right navigate headers,
/// Enter or Space changes sort order, and Down returns to the selected row.
public struct Table<Data: RandomAccessCollection, each Content: View>: View where Data.Element: Identifiable {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    @FocusState private var focus: TableFocus?
    private let data: Data
    private let selection: Binding<Data.Element.ID?>
    private let selectionPolicy: SelectionPolicy
    private let sortOrder: Binding<[KeyPathComparator<Data.Element>]>?
    private let columns: TableColumns<Data.Element, repeat each Content>
    private var activation: (@MainActor (Data.Element) -> Void)?

    /// Creates a table with bound row selection and typed columns.
    /// Supplying sort order enables sortable headers; the caller must apply the comparators to the data.
    /// The policy resolves absent IDs without rendering-time binding writes.
    public init(
        _ data: Data, selection: Binding<Data.Element.ID?>, selectionPolicy: SelectionPolicy = .firstVisible,
        sortOrder: Binding<[KeyPathComparator<Data.Element>]>? = nil,
        @TableColumnBuilder<Data.Element> columns: () -> TableColumns<Data.Element, repeat each Content>
    ) {
        self.data = data
        self.selection = selection
        self.selectionPolicy = selectionPolicy
        self.sortOrder = sortOrder
        self.columns = columns()
    }

    /// Activates an effective row on Enter instead of invoking `.onSubmit`.
    /// Header activation continues to sort without calling this action.
    public func onActivate(_ action: @escaping @MainActor (Data.Element) -> Void) -> Self {
        var view = self
        view.activation = action
        return view
    }

    private var selectedIndex: Data.Index? {
        selectionPolicy.index(in: data, selection: selection.wrappedValue, id: { $0.id })
    }

    private func handle(_ key: KeyEvent, headers: [Int]) -> KeyPressResult {
        guard [.arrowDown, .arrowUp, .home, .end, .enter].contains(key) else { return .ignored }
        if key == .arrowUp, !headers.isEmpty, data.isEmpty || selectedIndex == data.startIndex {
            return focusHeader(headers)
        }
        guard
            let index = selectionPolicy.navigationIndex(
                for: key, in: data, selection: selection.wrappedValue, id: { $0.id })
        else { return .handled }
        let element = data[index]
        selection.wrappedValue = element.id
        if key == .enter, let activation {
            activation(element)
            return .handled
        }
        return key == .enter ? .ignored : .handled
    }

    private func focusHeader(_ headers: [Int]) -> KeyPressResult {
        if let header = headers.first { focus = .header(header) }
        return .handled
    }

    private func sort(using comparator: KeyPathComparator<Data.Element>) {
        guard let sortOrder else { return }
        var updated = comparator
        let previous = sortOrder.wrappedValue
        if let primary = previous.first, primary.keyPath == comparator.keyPath {
            updated.order = primary.order == .forward ? .reverse : .forward
        }
        sortOrder.wrappedValue = [updated] + previous.filter { $0.keyPath != comparator.keyPath }
    }

    private func header(
        _ column: TableColumnDescription<Data.Element>, index: Int, headers: [Int]
    ) -> any View {
        guard sortOrder != nil, let comparator = column.comparator else { return Text(column.title) }
        let active = sortOrder?.wrappedValue.first { $0.keyPath == comparator.keyPath }
        let marker = active.map { $0.order == .forward ? " ↑" : " ↓" } ?? " ↕"
        return Button(column.title + marker) { sort(using: comparator) }
            .onKeyPress { key in
                switch key {
                case .space:
                    sort(using: comparator)
                case .arrowDown:
                    focus = .rows
                case .arrowUp:
                    break
                case .arrowLeft, .arrowRight:
                    if let position = headers.firstIndex(of: index) {
                        let next = position + (key == .arrowRight ? 1 : -1)
                        if headers.indices.contains(next) { focus = .header(headers[next]) }
                    }
                default: return .ignored
                }
                return .handled
            }
            .focused($focus, equals: .header(index))
    }
}

enum TableFocus: Hashable {
    case header(Int)
    case rows
}

extension Table: PrimitiveView {
    func makeDescription() -> ViewDescription {
        let descriptions = columns.descriptions()
        guard !descriptions.isEmpty else { return .empty }
        let headers = descriptions.indices.filter { sortOrder != nil && descriptions[$0].comparator != nil }
        let selectedID = selectedIndex.map { data[$0].id }
        let content = ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TableRow(
                    cells: descriptions.enumerated().map { header($0.element, index: $0.offset, headers: headers) })
                ListSelectionContent(
                    content: VStack(alignment: .leading, spacing: 0) {
                        ForEach(data) { element in
                            ListRow(
                                content: TableRow(cells: descriptions.map { $0.content(element) }),
                                isSelected: element.id == selectedID)
                        }
                    },
                    selection: selectedID.map(AnyHashable.init), handle: { handle($0, headers: headers) }
                )
                .focused($focus, equals: .rows)
            }
        }
        return .table(content.keyboardPane(), TableLayout(columnCount: descriptions.count))
    }
}

private struct TableRow: View, PrimitiveView {
    typealias Body = Never
    let cells: [any View]

    func makeDescription() -> ViewDescription {
        .tableRow(cells: cells.map { TableCell(content: $0) })
    }
}

private struct TableCell: View, PrimitiveView {
    typealias Body = Never
    let content: any View

    func makeDescription() -> ViewDescription {
        .group(children: [content], layout: HorizontalLayout(spacing: 0))
    }
}
