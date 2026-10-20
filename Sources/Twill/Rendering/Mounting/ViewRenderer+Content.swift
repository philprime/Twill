import Foundation

/// Converts descriptions into mounted children. It never lays out cells or writes output.
extension ViewRenderer {
    private static func describe<Content: View>(_ view: Content) -> ViewDescription {
        if let primitive = view as? any PrimitiveView { return primitive.makeDescription() }
        return .body(view.body)
    }

    func update(_ view: any View, at date: Date) {
        content.prepare(view) { [weak self] in self?.markDirty() }
        // Evaluate after releasing the storage mutation: a body can synchronously
        // write State and request follow-up work on this same mounted node.
        let previous = description
        let updated = Self.describe(view)
        description = updated
        switch updated {
        case .empty, .spacer, .divider, .drawing, .text, .textField, .textEditor, .keyHints, .menuButtonHints:
            removeChildren()
        case .canvas(let interval, _):
            removeChildren()
            schedule.updateCanvas(interval: interval, at: date)
        case .body(let body), .table(let body, _), .menu(let body, _):
            reconcile([body], at: date)
        case .dialog(let actions, _, let kind):
            updateDialog(actions, kind: kind, at: date)
        case .group(let views, _), .tableRow(let views), .split(let views, _):
            reconcile(views, at: date)
        case .keyed(let views):
            reconcileKeyed(views, at: date)
        case .scrollReader(let content, let proxy):
            if case .scrollReader(_, let previousProxy) = previous { previousProxy.renderer = nil }
            proxy.renderer = self
            reconcile([content], at: date)
        case .tab(let content, _, _), .disabled(let content, _), .keyboardShortcut(let content, _),
            .textLayout(let content, _), .tint(let content, _), .controlStyle(let content, _),
            .controlPresentation(let content, _, _), .controlSelection(let content, _),
            .focusable(let content), .control(let content, _),
            .focusBinding(let content, _), .submit(let content, _),
            .scroll(let content), .scrollIndicators(let content, _), .pane(let content),
            .listSelection(let content, _, _), .listRow(let content, _),
            .keyPress(let content, _), .styled(let content, _, _), .attributes(let content, _, _),
            .border(let content, _, _, _):
            reconcile([content], at: date)
        case .button, .task, .tabs, .sheet, .conditional, .timeline, .disclosure:
            updateSpecializedContent(updated, previous: previous, at: date)
        }
        updateTabState()
        schedule.collectDeadlines(retainedChildren.lazy.map(\.nextUpdate))
    }

    private func updateSpecializedContent(_ description: ViewDescription, previous: ViewDescription?, at date: Date) {
        switch description {
        case .button(let button):
            updateButtonContent(button.label, at: date)
        case .tabs(let content, _):
            reconcile([content], at: date)
        case .task(let content, let priority, let action):
            updateTask(content, priority: priority, action: action, at: date)
        case .disclosure(let header, let content):
            if content == nil { restoreFocusBeforeDisclosureCollapse() }
            reconcile(content.map { [header, $0] } ?? [header], at: date)
        case .sheet(let base, let isPresented, let content):
            let dismissing = !isPresented.wrappedValue && retainedChildren.count > 1
            reconcile(isPresented.wrappedValue ? [base, content()] : [base], at: date)
            if dismissing { restoreFocusAfterSheetDismissal() }
        case .conditional(let first, let content):
            updateConditional(first: first, content: content, previous: previous, at: date)
        case .timeline(let schedule, let content):
            let contextDate = self.schedule.advance(schedule, at: date)
            reconcile([content(contextDate)], at: date)
        default:
            break
        }
    }

    private func updateConditional(first: Bool, content: any View, previous: ViewDescription?, at date: Date) {
        if case .conditional(let wasFirst, _) = previous, first != wasFirst {
            removeChildren()
        }
        reconcile([content], at: date)
    }
}
