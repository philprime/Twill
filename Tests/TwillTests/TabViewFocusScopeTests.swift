import Testing

@testable import Twill

@Suite("Tab view focus scopes")
@MainActor
struct TabViewFocusScopeTests {
    private struct NestedEditorTabs: View {
        @State private var selection = 0
        @State private var firstText = ""
        @State private var secondText = ""
        let capture: (Binding<String>, Binding<String>) -> Void

        var body: some View {
            capture($firstText, $secondText)
            return ScrollView {
                TabView(selection: $selection) {
                    Tab("First", value: 0) { TextEditor(text: $firstText).frame(width: 12, height: 2) }
                    Tab("Second", value: 1) { TextEditor(text: $secondText).frame(width: 12, height: 2) }
                }
            }.frame(width: 30, height: 4, alignment: .topLeading)
        }
    }

    @Test("A tab view inside an outer scroll pane can reach its bar and restore editor focus")
    func enclosingScrollPane() throws {
        // -- Arrange --
        var first: Binding<String>?
        var second: Binding<String>?
        let renderer = ViewRenderer.make(
            NestedEditorTabs {
                first = $0
                second = $1
            })
        _ = renderer.render(.now)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.a)
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.shiftTab)
        let bar = try #require(renderer.render(.now).grid)
        let barCaret = renderer.caretPosition
        _ = renderer.handle(.arrowRight)
        _ = renderer.render(.now)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.b)
        _ = renderer.render(.now)
        _ = renderer.handle(KeyEvent(.pageUp, modifiers: .control))
        _ = renderer.render(.now)
        _ = renderer.handle(.c)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(bar.isFocused(column: 0, row: 0))
        #expect(!bar.isFocused(column: 0, row: 1))
        #expect(barCaret == nil)
        #expect(first?.wrappedValue == "ac")
        #expect(second?.wrappedValue == "b")
    }

    private struct FocusBindingTabs: View {
        @State private var selection = 0
        @FocusState private var firstFocused: Bool
        let capture: (FocusState<Bool>.Binding) -> Void

        var body: some View {
            capture($firstFocused)
            return TabView(selection: $selection) {
                Tab("First", value: 0) { Button("One") {}.focused($firstFocused) }
                Tab("Second", value: 1) { Button("Two") {} }
            }
        }
    }

    @Test("Inactive focus bindings clear so returning through the bar cannot steal focus")
    func inactiveBinding() throws {
        // -- Arrange --
        var focus: FocusState<Bool>.Binding?
        let renderer = ViewRenderer.make(FocusBindingTabs { focus = $0 })
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(.now)
        let initiallyFocused = focus?.wrappedValue

        // -- Act --
        _ = renderer.handle(KeyEvent(.pageDown, modifiers: .control))
        _ = renderer.render(.now)
        let inactiveFocus = focus?.wrappedValue
        _ = renderer.handle(.shiftTab)
        _ = renderer.handle(.arrowLeft)
        let bar = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(initiallyFocused == true)
        #expect(inactiveFocus == false)
        #expect(focus?.wrappedValue == false)
        #expect(bar.isFocused(column: 0, row: 0))
    }
}
