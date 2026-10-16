import Foundation

/// A labeled table column with typed cell content and an optional sort key.
public struct TableColumn<RowValue, Content: View> {
    let title: String
    let comparator: KeyPathComparator<RowValue>?
    let content: @MainActor (RowValue) -> Content

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
}
