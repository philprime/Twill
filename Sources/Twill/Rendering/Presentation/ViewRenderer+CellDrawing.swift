import Foundation

/// Adapts mounted descriptions and memories into node-local presentation snapshots.
extension ViewRenderer {
    var nodePresentation: NodePresentation {
        switch description {
        case .spacer(let minimum):
            return .drawing(SpacerDrawing(axis: layoutState.stackAxis, minimum: minimum), caretColumn: nil)
        case .divider:
            return .drawing(DividerDrawing(axis: dividerAxis), caretColumn: nil)
        case .keyHints(let hints):
            let text = isEnabled ? hints.compactMap(\.text).joined(separator: "  •  ") : ""
            return .drawing(TextDrawing(text), caretColumn: nil)
        case .styled(_, _, .some):
            return .background(layoutState.background)
        case .border(_, let glyphs, let style, let title):
            let color: Color?
            if let style { color = style.resolve(in: layoutState.theme) } else { color = layoutState.foreground }
            return .border(glyphs: glyphs, color: color, title: title)
        case .scroll: return .scroll(offset: scrollState.offset, contentHeight: scrollState.contentHeight)
        case .textEditor(let editor):
            return .editor(snapshot: editor.snapshot, offset: editorState.offset)
        case .drawing(let drawing): return .drawing(drawing, caretColumn: nil)
        case .text(let drawing): return .drawing(drawing.configured(textLayout), caretColumn: nil)
        case .canvas(_, let render):
            return .drawing(
                Canvas.Drawing(size: layoutState.size, date: schedule.canvasDate ?? .now, render: render),
                caretColumn: nil)
        case .textField(let field): return .drawing(field.drawing, caretColumn: field.caretColumn)
        case .tabs: return .tabs(bar: tabBar)
        default: return .content
        }
    }

    func draw(in context: inout DrawingContext, focused: ViewRenderer?) {
        let presentation = nodePresentation
        let appearance = controlAppearance(focused: focused)
        let foreground: Color?
        if let style = appearance.foreground {
            foreground = style.resolve(in: layoutState.theme)
        } else {
            foreground = layoutState.foreground
        }
        let background: Color?
        if let style = appearance.background {
            background = style.resolve(in: layoutState.theme)
        } else {
            background = layoutState.background
        }
        let highlight: Bool?
        switch appearance.focusEffect {
        case .automatic: highlight = nil
        case .none: highlight = false
        case .reversed: highlight = true
        }
        context.withAttributes(appearance.attributes ?? layoutState.attributes, mask: .supported) { region in
            region.withColors(
                foreground: foreground, background: background,
                usesTerminalBackground: (appearance.background != nil || layoutState.hasBackgroundStyle)
                    && background == nil
            ) { region in
                if appearance.background != nil { region.fillBackground(background, size: layoutState.size) }
                presentation.draw(
                    in: &region,
                    context: NodePresentationContext(
                        size: layoutState.size, isFocused: presentation.usesFocusAppearance && isInsideFocus(focused),
                        isDirectlyFocused: focused === self, focusHighlight: highlight,
                        drawChildren: { region in
                            for placement in self.layoutState.placements {
                                region.withRegion(placement.bounds) { placement.node.draw(in: &$0, focused: focused) }
                            }
                        }))
            }
        }
    }

    private func isInsideFocus(_ focused: ViewRenderer?) -> Bool {
        var node: ViewRenderer? = self
        while let current = node {
            if case .listRow(_, let isSelected) = current.description { return isSelected }
            if case .disabled(_, true) = current.description { return false }
            if case .button(let button) = current.description, !button.isEnabled { return false }
            // Viewers and keyboard scopes do not highlight all their static descendants.
            if case .scroll = current.description { return false }
            if case .pane = current.description { return false }
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
