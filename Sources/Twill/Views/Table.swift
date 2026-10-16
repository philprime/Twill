import Foundation

/// A single-selection table in one scrolling keyboard pane.
/// Sortable headers update the bound comparators; the caller sorts the data.
/// Up from the first row reaches the headers. Left/Right navigate headers,
/// Enter or Space changes sort order, and Down returns to the selected row.
public struct Table<Data: RandomAccessCollection, each Content: View>: View where Data.Element: Identifiable {
    public typealias Body = Never
    @FocusState private var focus: TableFocus?
    private let data: Data
    private let selection: Binding<Data.Element.ID?>
    private let sortOrder: Binding<[KeyPathComparator<Data.Element>]>?
    private let columns: TableColumns<Data.Element, repeat each Content>

    public init(
        _ data: Data, selection: Binding<Data.Element.ID?>,
        sortOrder: Binding<[KeyPathComparator<Data.Element>]>? = nil,
        @TableColumnBuilder<Data.Element> columns: () -> TableColumns<Data.Element, repeat each Content>
    ) {
        self.data = data
        self.selection = selection
        self.sortOrder = sortOrder
        self.columns = columns()
    }

    private var selectedIndex: Data.Index? {
        data.firstIndex { $0.id == selection.wrappedValue } ?? (data.isEmpty ? nil : data.startIndex)
    }

    private func handle(_ key: KeyEvent, headers: [Int]) -> KeyPressResult {
        guard [.arrowDown, .arrowUp, .home, .end, .enter].contains(key) else { return .ignored }
        guard var index = selectedIndex else {
            return key == .arrowUp ? focusHeader(headers) : .handled
        }
        switch key {
        case .arrowDown:
            let next = data.index(after: index)
            if next != data.endIndex { index = next }
        case .arrowUp:
            if index != data.startIndex {
                index = data.index(before: index)
            } else if !headers.isEmpty {
                return focusHeader(headers)
            }
        case .home: index = data.startIndex
        case .end: index = data.index(before: data.endIndex)
        default: break
        }
        selection.wrappedValue = data[index].id
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
        return .group(children: [content], layout: TableLayout(columnCount: descriptions.count))
    }
}

private struct TableRow: View, PrimitiveView {
    typealias Body = Never
    let cells: [any View]

    func makeDescription() -> ViewDescription {
        .group(children: cells.map { TableCell(content: $0) }, layout: TableRowLayout())
    }
}

private struct TableCell: View, PrimitiveView {
    typealias Body = Never
    let content: any View

    func makeDescription() -> ViewDescription {
        .group(children: [content], layout: HorizontalLayout(spacing: 0))
    }
}
