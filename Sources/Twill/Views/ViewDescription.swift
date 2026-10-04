import Foundation

/// Primitive descriptions are internal; application views only expose their body.
@MainActor
protocol PrimitiveView {
    func makeDescription() -> ViewDescription
}

@MainActor
enum ViewDescription {
    case empty
    case drawing(any PrimitiveDrawing)
    case canvas(interval: TimeInterval?, render: @MainActor (Canvas.Context, Canvas.Size) -> Void)
    case textField(TextFieldDescription)
    case body(any View)
    case group(children: [any View], layout: (any PrimitiveLayout)?)
    case keyed(children: [(id: AnyHashable, view: any View)])
    case focusable(any View)
    case scroll(any View)
    case scrollReader(any View, ScrollViewProxy)
    case styled(any View, foreground: Color?, background: Color?)
    case border(any View, glyphs: Border.Glyphs, color: Color)
    case keyPress(any View, @MainActor (KeyEvent) -> KeyPressResult)
    case task(any View, priority: TaskPriority, action: @MainActor @Sendable () async -> Void)
    case sheet(base: any View, isPresented: Binding<Bool>, content: @MainActor () -> any View)
    case conditional(first: Bool, content: any View)
    case timeline(PeriodicTimelineSchedule, @MainActor (Date) -> any View)
}
