import Foundation

/// Primitive descriptions are internal; application views only expose their body.
@MainActor
protocol PrimitiveView {
    func makeDescription() -> ViewDescription
}

@MainActor
enum ViewDescription {
    case empty
    case spacer(Int)
    case divider(Axis?)
    case drawing(any PrimitiveDrawing)
    case text(MultilineTextDrawing)
    case textLayout(any View, TextLayoutChange)
    case canvas(interval: TimeInterval?, render: @MainActor (Canvas.Context, Canvas.Size) -> Void)
    case textField(TextFieldDescription)
    case textEditor(TextEditorDescription)
    case tab(any View, title: String, value: AnyHashable)
    case tabs(any View, selection: Binding<AnyHashable>)
    case body(any View)
    case button(ButtonDescription)
    case keyHints([KeyHintDescription])
    case dialog(any View, isPresented: Binding<Bool>, kind: DialogKind)
    case disclosure(header: any View, content: (any View)?)
    case group(children: [any View], layout: (any PrimitiveLayout)?)
    // Shared-column ownership is structural, not a concrete-layout tag on a generic group.
    // Rows require a table-local measurement context and preserve even empty cell slots.
    case table(any View, TableLayout)
    case tableRow(cells: [any View])
    case keyed(children: [(id: AnyHashable, view: any View)])
    case disabled(any View, Bool)
    case focusable(any View)
    case control(any View, ControlInteraction)
    case focusBinding(any View, FocusBindingDescription)
    case submit(any View, @MainActor () -> Void)
    case listSelection(any View, AnyHashable?, @MainActor (KeyEvent) -> KeyPressResult)
    case listRow(any View, isSelected: Bool)
    case scroll(any View)
    case scrollIndicators(any View, ScrollIndicatorVisibility)
    case pane(any View)
    case scrollReader(any View, ScrollViewProxy)
    case styled(any View, foreground: (any Style)?, background: (any Style)?)
    case theme(any View, Theme)
    case controlStyle(any View, any ControlStyle)
    case controlPresentation(any View, kind: ControlKind, selected: Bool)
    case controlSelection(any View, Bool)
    case attributes(any View, TextAttributes, mask: TextAttributes)
    case border(any View, glyphs: Border.Glyphs, color: (any Style)?, title: TextDrawing? = nil)
    case keyPress(any View, @MainActor (KeyEvent) -> KeyPressResult)
    case keyboardShortcut(any View, [KeyboardShortcut])
    case task(any View, priority: TaskPriority, action: @MainActor @Sendable () async -> Void)
    case sheet(base: any View, isPresented: Binding<Bool>, content: @MainActor () -> any View)
    case conditional(first: Bool, content: any View)
    case timeline(PeriodicTimelineSchedule, @MainActor (Date) -> any View)
}
