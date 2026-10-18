/// Shared column geometry for one table's current measurement pass.
///
/// The table resolves headers and retained rows together, then passes these widths down
/// through child measurement. Rows do not search ancestors or read a previously cached
/// frame. A nested table starts its own context, so outer widths cannot affect its columns.
/// This value contains no nodes or closures and is not retained as mounted control state.
struct TableLayoutContext {
    let columnWidths: [Int]
}
