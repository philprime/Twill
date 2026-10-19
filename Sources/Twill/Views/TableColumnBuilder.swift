/// Builds a fixed set of columns while retaining every cell's concrete type.
@resultBuilder
@MainActor
public enum TableColumnBuilder<RowValue> {
    /// Accepts a typed column expression without erasing its cell content type.
    public static func buildExpression<Content: View>(
        _ column: TableColumn<RowValue, Content>
    ) -> TableColumn<RowValue, Content> {
        column
    }

    /// Combines columns in display order while preserving each cell content type.
    public static func buildBlock<each Content: View>(
        _ columns: repeat TableColumn<RowValue, each Content>
    ) -> TableColumns<RowValue, repeat each Content> {
        TableColumns(columns: (repeat each columns))
    }
}

/// A fixed collection of table columns retaining the concrete content type of every column.
public struct TableColumns<RowValue, each Content: View> {
    let columns: (repeat TableColumn<RowValue, each Content>)

    @MainActor
    func descriptions() -> [TableColumnDescription<RowValue>] {
        var result: [TableColumnDescription<RowValue>] = []
        for column in repeat each columns {
            result.append(
                TableColumnDescription(
                    title: column.title, comparator: column.comparator, content: column.content,
                    width: column.widthPolicy, alignment: column.alignment))
        }
        return result
    }
}
