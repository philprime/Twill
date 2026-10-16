/// Builds a fixed set of columns while retaining every cell's concrete type.
@resultBuilder
@MainActor
public enum TableColumnBuilder<RowValue> {
    public static func buildExpression<Content: View>(
        _ column: TableColumn<RowValue, Content>
    ) -> TableColumn<RowValue, Content> {
        column
    }

    public static func buildBlock<each Content: View>(
        _ columns: repeat TableColumn<RowValue, each Content>
    ) -> TableColumns<RowValue, repeat each Content> {
        TableColumns(columns: (repeat each columns))
    }
}

public struct TableColumns<RowValue, each Content: View> {
    let columns: (repeat TableColumn<RowValue, each Content>)

    @MainActor
    func descriptions() -> [TableColumnDescription<RowValue>] {
        var result: [TableColumnDescription<RowValue>] = []
        for column in repeat each columns {
            result.append(
                TableColumnDescription(title: column.title, comparator: column.comparator, content: column.content))
        }
        return result
    }
}
