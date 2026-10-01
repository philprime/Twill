/// Draws mounted descriptions into the host's shared cell grid.
extension ViewRenderer {
    func draw(in context: inout DrawingContext, focused: ViewRenderer?) {
        if case .styled(_, let foreground, let background) = description {
            context.withStyle(foreground: foreground, background: background, size: measuredSize) { region in
                drawChildren(in: &region, focused: focused)
            }
        } else if case .border(_, let glyphs, let color) = description {
            drawBorder(glyphs, color: color, in: &context, focused: focused)
        } else if case .scroll = description {
            let viewport = CellRect(column: 0, row: 0, width: measuredSize.width, height: measuredSize.height)
            context.withRegion(viewport) { viewport in
                viewport.withRegion(
                    CellRect(column: 0, row: -scrollOffset, width: measuredSize.width, height: scrollContentHeight)
                ) { content in
                    drawChildren(in: &content, focused: focused)
                }
            }
        } else if let drawing {
            let active = isInsideFocus(focused)
            context.withFocus(active) { region in
                drawing.draw(in: &region)
                if active, case .textField(let field) = description, let column = field.caretColumn {
                    region.placeCaret(column: column, row: 0)
                }
            }
        } else {
            drawChildren(in: &context, focused: focused)
        }
    }

    private func drawBorder(
        _ glyphs: Border.Glyphs, color: Color, in context: inout DrawingContext, focused: ViewRenderer?
    ) {
        let width = measuredSize.width
        let height = measuredSize.height
        guard width >= 2, height >= 2 else { return }
        context.withStyle(foreground: color, background: nil, size: measuredSize) { region in
            region.draw(glyphs.topLeft, width: 1, column: 0, row: 0)
            region.draw(glyphs.topRight, width: 1, column: width - 1, row: 0)
            region.draw(glyphs.bottomLeft, width: 1, column: 0, row: height - 1)
            region.draw(glyphs.bottomRight, width: 1, column: width - 1, row: height - 1)
            for column in 1..<(width - 1) {
                region.draw(glyphs.top, width: 1, column: column, row: 0)
                region.draw(glyphs.bottom, width: 1, column: column, row: height - 1)
            }
            for row in 1..<(height - 1) {
                region.draw(glyphs.left, width: 1, column: 0, row: row)
                region.draw(glyphs.right, width: 1, column: width - 1, row: row)
            }
        }
        context.withRegion(CellRect(column: 1, row: 1, width: width - 2, height: height - 2)) {
            drawChildren(in: &$0, focused: focused)
        }
    }

    private func drawChildren(in context: inout DrawingContext, focused: ViewRenderer?) {
        for placement in placements {
            context.withRegion(placement.bounds) { placement.node.draw(in: &$0, focused: focused) }
        }
    }

    func revealFocus(_ focused: ViewRenderer?) {
        if case .scroll = description, let focused, focused !== self {
            reveal(focused)
        }
        for child in children { child.revealFocus(focused) }
    }

    private func reveal(_ focused: ViewRenderer) {
        guard let rect = bounds(of: focused, column: 0, row: 0) else { return }
        if rect.row < scrollOffset {
            scrollOffset = rect.row
        } else if rect.row + rect.height > scrollOffset + measuredSize.height {
            scrollOffset = rect.row + rect.height - measuredSize.height
        }
        scrollOffset = min(max(0, scrollOffset), max(0, scrollContentHeight - measuredSize.height))
    }

    private func bounds(of target: ViewRenderer, column: Int, row: Int) -> CellRect? {
        for placement in placements {
            let bounds = placement.bounds
            let originX = column + bounds.column
            let originY = row + bounds.row
            var ancestor: ViewRenderer? = placement.node
            while let node = ancestor {
                if node === target {
                    return CellRect(column: originX, row: originY, width: bounds.width, height: bounds.height)
                }
                if node === self { break }
                ancestor = node.parent
            }
            if let found = placement.node.bounds(of: target, column: originX, row: originY) { return found }
        }
        return nil
    }

    private func isInsideFocus(_ focused: ViewRenderer?) -> Bool {
        guard let focused else { return false }
        var node: ViewRenderer? = self
        while let current = node {
            if current === focused { return true }
            // Nested focusable controls retain their own appearance and identity.
            if case .focusable = current.description { return false }
            node = current.parent
        }
        return false
    }
}
