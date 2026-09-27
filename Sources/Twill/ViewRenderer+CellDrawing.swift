/// Draws mounted descriptions into the host's shared cell grid.
extension ViewRenderer {
    func draw(in context: inout DrawingContext, focused: ViewRenderer?) {
        if case .styled(_, let foreground, let background) = description {
            context.withStyle(foreground: foreground, background: background, size: measuredSize) { region in
                drawChildren(in: &region, focused: focused)
            }
        } else if case .border(_, let glyphs, let color) = description {
            drawBorder(glyphs, color: color, in: &context, focused: focused)
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
