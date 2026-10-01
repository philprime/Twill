/// Lays out mounted cells in rows and distributes terminal columns among flexible grid items.
struct GridLayout: PrimitiveLayout {
    let columns: [GridItem]
    let spacing: Int

    func sizeThatFits(_ proposal: ProposedCellSize, subviews: [CellSize]) -> CellSize {
        guard !subviews.isEmpty else { return .zero }
        let widths = columnWidths(in: proposal.width ?? intrinsicWidth(for: subviews), subviews: subviews)
        let heights = rowHeights(for: subviews)
        let width = widths.reduce(0, +) + (columns.count - 1) * spacing
        let height = heights.reduce(0, +) + (heights.count - 1) * spacing
        return proposal.constrain(CellSize(width: width, height: height))
    }

    func placeSubviews(_ subviews: [CellSize], in size: CellSize) -> [CellRect] {
        guard !subviews.isEmpty else { return [] }
        let widths = columnWidths(in: size.width, subviews: subviews)
        let heights = rowHeights(for: subviews)
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
            let columnIndex = index % columns.count
            let rowIndex = index / columns.count
            return CellRect(
                column: offsets[columnIndex], row: rowOffsets[rowIndex],
                width: widths[columnIndex], height: heights[rowIndex])
        }
    }

    func columnWidths(in width: Int, subviews: [CellSize]) -> [Int] {
        let natural = intrinsicWidths(for: subviews)
        if width == intrinsicWidth(for: subviews) { return natural }

        var widths = columns.map { item in
            switch item.size {
            case .flexible(let minimum, _): return minimum
            }
        }
        let limits = columns.map { item in
            switch item.size {
            case .flexible(_, let maximum): return maximum
            }
        }
        let gaps = (columns.count - 1) * spacing
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

    private func intrinsicWidth(for subviews: [CellSize]) -> Int {
        intrinsicWidths(for: subviews).reduce(0, +) + (columns.count - 1) * spacing
    }

    private func intrinsicWidths(for subviews: [CellSize]) -> [Int] {
        columns.indices.map { column in
            let natural =
                stride(from: column, to: subviews.count, by: columns.count)
                .map { subviews[$0].width }.max() ?? 0
            switch columns[column].size {
            case .flexible(let minimum, let maximum): return min(max(natural, minimum), maximum)
            }
        }
    }

    private func rowHeights(for subviews: [CellSize]) -> [Int] {
        stride(from: 0, to: subviews.count, by: columns.count).map { start in
            subviews[start..<min(start + columns.count, subviews.count)].map(\.height).max() ?? 0
        }
    }
}
