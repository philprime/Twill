extension NodePresentation {
    func draw(in drawing: inout DrawingContext, context: NodePresentationContext) {
        switch self {
        case .content:
            context.drawChildren(&drawing)
        case .drawing(let primitive, let caretColumn):
            drawing.withFocus(context.isFocused) { region in
                primitive.draw(in: &region)
                if context.isFocused, let caretColumn { region.placeCaret(column: caretColumn, row: 0) }
            }
        case .background(let color):
            drawing.fillBackground(color, size: context.size)
            context.drawChildren(&drawing)
        case .border(let glyphs, let style, let title):
            drawBorder(glyphs, style: style, title: title, in: &drawing, context: context)
        case .scroll(let offset, let contentHeight):
            let viewport = CellRect(origin: .zero, size: context.size)
            drawing.withRegion(viewport) { viewport in
                viewport.withRegion(
                    CellRect(column: 0, row: -offset, width: context.size.width, height: contentHeight)
                ) { content in context.drawChildren(&content) }
            }
        case .editor(let snapshot, let offset):
            drawEditor(snapshot, offset: offset, in: &drawing, context: context)
        case .tabs(let bar):
            drawing.withRegion(CellRect(column: 0, row: 0, width: context.size.width, height: 1)) { region in
                region.withFocus(context.isDirectlyFocused) { bar.draw(in: &$0) }
            }
            context.drawChildren(&drawing)
        }
    }

    private func drawBorder(
        _ glyphs: Border.Glyphs, style: ResolvedStyle, title: TextDrawing?, in drawing: inout DrawingContext,
        context: NodePresentationContext
    ) {
        let width = context.size.width
        let height = context.size.height
        guard width >= 2, height >= 2 else { return }
        drawing.withForeground(style.color) { region in
            region.withAttributes(style.attributes, mask: style.attributes) { region in
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
        }
        drawing.withRegion(CellRect(column: 1, row: 1, width: width - 2, height: height - 2)) { region in
            context.drawChildren(&region)
        }
    }

    private func drawEditor(
        _ snapshot: TextEditorSnapshot, offset: CellPosition,
        in drawing: inout DrawingContext, context: NodePresentationContext
    ) {
        let size = context.size
        guard size.width > 0, size.height > 0 else { return }
        let content = snapshot.layout(width: size.width)
        let caret = content.position(at: snapshot.caret, upstream: snapshot.upstream)
        drawing.withRegion(CellRect(origin: .zero, size: size)) { viewport in
            viewport.withFocus(context.isFocused) { region in
                let end = min(content.lines.count, offset.row + size.height)
                for row in offset.row..<end {
                    region.withRegion(
                        CellRect(
                            column: -offset.column, row: row - offset.row,
                            width: content.drawingWidth, height: 1)
                    ) { content.lines[row].drawing.draw(in: &$0) }
                }
            }
            if context.isFocused {
                viewport.placeCaret(column: caret.column - offset.column, row: caret.row - offset.row)
            }
        }
    }
}
