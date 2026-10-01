/// Lays out mounted cells in rows and distributes terminal columns among flexible grid items.
struct GridLayout: PrimitiveLayout {
    let columns: [GridItem]
    let spacing: Int

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        guard !subviews.isEmpty else { return .zero }
        let width = proposal.width ?? intrinsicWidth(for: subviews, columns: columns)
        let resolved = columns(in: width)
        let widths = columnWidths(in: width, subviews: subviews)
        let heights = rowHeights(for: subviews, columnCount: resolved.count)
        let contentWidth = widths.reduce(0, +) + (resolved.count - 1) * spacing
        let height = heights.reduce(0, +) + (heights.count - 1) * spacing
        return proposal.constrain(CellSize(width: contentWidth, height: height))
    }

    func placeSubviews(_ subviews: [CellSize], in size: CellSize) -> [CellRect] {
        guard !subviews.isEmpty else { return [] }
        let widths = columnWidths(in: size.width, subviews: subviews)
        let heights = rowHeights(for: subviews, columnCount: widths.count)
        var column = 0
        let offsets = widths.map { width in
            defer { column += width + spacing }
            return column
        }
        var row = 0
        let rowOffsets = heights.map { height in
            defer { row += height + spacing }
            return row
        }
        return subviews.indices.map { index in
            let columnIndex = index % widths.count
            let rowIndex = index / widths.count
            return CellRect(
                column: offsets[columnIndex], row: rowOffsets[rowIndex],
                width: widths[columnIndex], height: heights[rowIndex])
        }
    }

    func columnWidths(in width: Int, subviews: [CellSize]) -> [Int] {
        let resolved = columns(in: width)
        let natural = intrinsicWidths(for: subviews, columns: resolved)
        if width == intrinsicWidth(for: subviews, columns: resolved) { return natural }

        var widths = resolved.map { item in
            switch item.size {
            case .flexible(let minimum, _), .adaptive(let minimum): return minimum
            }
        }
        let limits = resolved.map { item in
            switch item.size {
            case .flexible(_, let maximum): return maximum
            case .adaptive: return Int.max
            }
        }
        let gaps = (resolved.count - 1) * spacing
        var remaining = max(0, width - gaps - widths.reduce(0, +))
        while remaining > 0 {
            let eligible = widths.indices.filter { widths[$0] < limits[$0] }
            guard !eligible.isEmpty else { break }
            let share = max(1, remaining / eligible.count)
            for index in eligible {
                let addition = min(share, limits[index] - widths[index], remaining)
                widths[index] += addition
                remaining -= addition
            }
        }
        return widths
    }

    private func columns(in width: Int) -> [GridItem] {
        guard columns.count == 1, case .adaptive(let minimum) = columns[0].size else { return columns }
        let count = max(1, (width + spacing) / (minimum + spacing))
        return Array(repeating: columns[0], count: count)
    }

    private func intrinsicWidth(for subviews: [CellSize], columns: [GridItem]) -> Int {
        intrinsicWidths(for: subviews, columns: columns).reduce(0, +) + (columns.count - 1) * spacing
    }

    private func intrinsicWidths(for subviews: [CellSize], columns: [GridItem]) -> [Int] {
        columns.indices.map { column in
            let natural =
                stride(from: column, to: subviews.count, by: columns.count)
                .map { subviews[$0].width }.max() ?? 0
            switch columns[column].size {
            case .flexible(let minimum, let maximum): return min(max(natural, minimum), maximum)
            case .adaptive(let minimum): return max(natural, minimum)
            }
        }
    }

    private func rowHeights(for subviews: [CellSize], columnCount: Int) -> [Int] {
        stride(from: 0, to: subviews.count, by: columnCount).map { start in
            subviews[start..<min(start + columnCount, subviews.count)].map(\.height).max() ?? 0
        }
    }
}
