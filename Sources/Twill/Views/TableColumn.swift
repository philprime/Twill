import Foundation

/// A labeled table column with typed cell content and an optional sort key.
public struct TableColumn<RowValue, Content: View> {
    let title: String
    let comparator: KeyPathComparator<RowValue>?
    let content: @MainActor (RowValue) -> Content
    private(set) var widthPolicy: TableColumnWidth = .automatic
    private(set) var alignment: HorizontalAlignment = .leading

    /// Creates a column with custom cell content and no sort key.
    public init(_ title: String, @ViewBuilder content: @escaping @MainActor (RowValue) -> Content) {
        self.title = title
        self.comparator = nil
        self.content = content
    }

    /// Creates a column with custom cell content and a comparable key path for header sorting.
    public init<Value: Comparable>(
        _ title: String, value: KeyPath<RowValue, Value> & Sendable,
        @ViewBuilder content: @escaping @MainActor (RowValue) -> Content
    ) {
        self.title = title
        self.comparator = KeyPathComparator(value)
        self.content = content
    }
    /// Sets an exact width in terminal cells.
    public func width(_ cells: Int) -> Self { width(.fixed(cells)) }

    /// Sets shared header/body width constraints. Fixed widths and flexible
    /// minimums may extend beyond scarce viewport space and remain clipped.
    public func width(_ policy: TableColumnWidth) -> Self {
        switch policy {
        case .automatic: break
        case .fixed(let width): precondition(width >= 0, "Column width must not be negative")
        case .flexible(let minimum, let maximum):
            precondition(minimum >= 0 && maximum >= minimum, "Column bounds must be ordered and nonnegative")
        }
        var column = self
        column.widthPolicy = policy
        return column
    }

    /// Aligns cell content within its shared column width, with top vertical alignment.
    public func alignment(_ alignment: HorizontalAlignment) -> Self {
        var column = self
        column.alignment = alignment
        return column
    }
}

extension TableColumn where Content == Text {
    /// Creates a sortable text column displaying the string at the supplied key path.
    public init(_ title: String, value: KeyPath<RowValue, String> & Sendable) {
        self.title = title
        self.comparator = KeyPathComparator(value)
        self.content = { Text($0[keyPath: value]) }
    }
}

struct TableColumnDescription<RowValue> {
    let title: String
    let comparator: KeyPathComparator<RowValue>?
    let content: @MainActor (RowValue) -> any View
    let width: TableColumnWidth
    let alignment: HorizontalAlignment
}
