/// Draws mounted descriptions into the host's shared cell grid.
extension ViewRenderer {
    func draw(in context: inout DrawingContext, focused: ViewRenderer?) {
        if case .tabs = description { drawTabBar(in: &context, focused: focused) }
        if case .button(_, .destructive, _) = description {
            context.withStyle(foreground: .red, background: nil, size: layoutState.size) { region in
                drawChildren(in: &region, focused: focused)
            }
        } else if case .styled(_, let foreground, let background) = description {
            context.withStyle(foreground: foreground, background: background, size: layoutState.size) { region in
                drawChildren(in: &region, focused: focused)
            }
        } else if case .border(_, let glyphs, let color, let title) = description {
            drawBorder(glyphs, color: color, title: title, in: &context, focused: focused)
        } else if case .scroll = description {
            let viewport = CellRect(column: 0, row: 0, width: layoutState.size.width, height: layoutState.size.height)
            context.withRegion(viewport) { viewport in
                viewport.withRegion(
                    CellRect(
                        column: 0, row: -scrollState.offset, width: layoutState.size.width,
                        height: scrollState.contentHeight)
                ) { content in
                    drawChildren(in: &content, focused: focused)
                }
            }
        } else if case .textEditor(let editor) = description {
            drawTextEditor(editor, in: &context, active: isInsideFocus(focused))
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
        _ glyphs: Border.Glyphs, color: Color?, title: TextDrawing?, in context: inout DrawingContext,
        focused: ViewRenderer?
    ) {
        let width = layoutState.size.width
        let height = layoutState.size.height
        guard width >= 2, height >= 2 else { return }
        context.withStyle(foreground: color, background: nil, size: layoutState.size) { region in
            region.draw(glyphs.topLeft, width: 1, column: 0, row: 0)
            region.draw(glyphs.topRight, width: 1, column: width - 1, row: 0)
            region.draw(glyphs.bottomLeft, width: 1, column: 0, row: height - 1)
            region.draw(glyphs.bottomRight, width: 1, column: width - 1, row: height - 1)
            for column in 1..<(width - 1) {
                region.draw(glyphs.top, width: 1, column: column, row: 0)
                region.draw(glyphs.bottom, width: 1, column: column, row: height - 1)
            }
            // Clip within the top edge so a long or wide title cannot overwrite a corner.
            if let title, width > 3 {
                region.withRegion(CellRect(column: 2, row: 0, width: width - 3, height: 1)) {
                    title.draw(in: &$0)
                }
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
        for placement in layoutState.placements {
            context.withRegion(placement.bounds) { placement.node.draw(in: &$0, focused: focused) }
        }
    }

    private func isInsideFocus(_ focused: ViewRenderer?) -> Bool {
        var node: ViewRenderer? = self
        while let current = node {
            if case .listRow(_, let isSelected) = current.description { return isSelected }
            // Focusing a scroll pane enables navigation without highlighting all its content.
            if case .scroll = current.description { return false }
            // The tab bar is its own focus target, not a container highlight or caret.
            if case .tabs = current.description { return false }
            if current === focused { return true }
            // Nested focusable controls retain their own appearance and identity.
            if case .focusable = current.description { return false }
            node = current.parent
        }
        return false
    }
}
