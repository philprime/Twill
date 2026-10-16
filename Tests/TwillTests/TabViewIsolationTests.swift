import Testing

@testable import Twill

@Suite("Tab view isolation")
@MainActor
struct TabViewIsolationTests {
    private struct EditingTabs: View {
        @State private var selection = 0
        @State private var firstText = ""
        @State private var secondText = ""
        @FocusState private var secondFocused = true
        let multiline: Bool
        let capture: (Binding<String>, Binding<String>) -> Void

        var body: some View {
            capture($firstText, $secondText)
            return TabView(selection: $selection) {
                Tab("First", value: 0) { editor($firstText) }
                Tab("Second", value: 1) {
                    editor($secondText).focused($secondFocused)
                }
                .focused($secondFocused)
            }
        }

        @ViewBuilder
        private func editor(_ text: Binding<String>) -> some View {
            if multiline {
                TextEditor(text: text)
            } else {
                TextField("Field", text: text)
            }
        }
    }

    @Test("Hidden focus requests cannot steal typing and editing survives tab switches", arguments: [false, true])
    func editingIsolation(multiline: Bool) throws {
        // -- Arrange --
        var first: Binding<String>?
        var second: Binding<String>?
        let renderer = ViewRenderer.make(
            EditingTabs(multiline: multiline) {
                first = $0
                second = $1
            })
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)

        // -- Act --
        _ = renderer.handle(.a)
        _ = renderer.render(.now)
        _ = renderer.handle(KeyEvent(.pageDown, modifiers: .control))
        _ = renderer.render(.now)
        _ = renderer.handle(.b)
        _ = renderer.render(.now)
        _ = renderer.handle(KeyEvent(.pageUp, modifiers: .control))
        let restored = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.c)
        _ = renderer.render(.now)
        _ = renderer.handle(.shiftTab)
        let bar = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.d)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(first?.wrappedValue == "acd")
        #expect(second?.wrappedValue == "b")
        #expect(restored.isFocused(column: 0, row: 1))
        #expect(bar.isFocused(column: 0, row: 0))
        #expect(renderer.caretPosition == CellPosition(column: 3, row: 1))
    }

    private struct PanePage: View {
        let activate: (String) -> Void

        var body: some View {
            HStack {
                ScrollView {
                    VStack {
                        Button("A1") { activate("A1") }
                        Button("A2") { activate("A2") }
                    }
                }.frame(height: 2)
                ScrollView {
                    VStack {
                        Button("B1") { activate("B1") }
                        Button("B2") { activate("B2") }
                    }
                }.frame(height: 2)
            }
        }
    }

    private struct PaneTabs: View {
        @State private var selection = 0
        let activate: (String) -> Void

        var body: some View {
            TabView(selection: $selection) {
                Tab("First", value: 0) { PanePage(activate: activate) }
                Tab("Second", value: 1) { Button("Other") {} }
            }
        }
    }

    @Test("Shift-Tab reaches the bar from a scroll pane and Tab returns to its content")
    func barAccessFromPane() throws {
        // -- Arrange --
        var activated: [String] = []
        let renderer = ViewRenderer.make(PaneTabs { activated.append($0) })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.shiftTab)
        let bar = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowRight)
        let second = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.render(.now)
        _ = renderer.handle(.tab)
        let content = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(bar.isFocused(column: 0, row: 0))
        #expect(second.snapshotText.hasPrefix("First [Second]"))
        #expect(second.snapshotText.contains("Other"))
        #expect(content.isFocused(column: 0, row: 1))
        #expect(activated == ["A1"])
    }

    @Test("Entering a tab from the bar restores its remembered nonfirst pane")
    func rememberedPaneFromBar() {
        // -- Arrange --
        var activated: [String] = []
        let renderer = ViewRenderer.make(PaneTabs { activated.append($0) })
        _ = renderer.render(.now)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(KeyEvent(.pageDown, modifiers: .control))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.shiftTab)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.render(.now)
        _ = renderer.handle(.tab)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(activated == ["B2"])
    }

    @Test("Switching back restores the active pane and its focused descendant")
    func paneRestoration() {
        // -- Arrange --
        var activated: [String] = []
        let renderer = ViewRenderer.make(PaneTabs { activated.append($0) })
        _ = renderer.render(.now)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.arrowDown)

        // -- Act --
        _ = renderer.handle(KeyEvent(.pageDown, modifiers: .control))
        _ = renderer.render(.now)
        _ = renderer.handle(KeyEvent(.pageUp, modifiers: .control))
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(activated == ["B2"])
    }

    private struct SheetTabs: View {
        @State private var selection = 0
        @State private var presented = true
        let capture: (Binding<Int>) -> Void
        let sheetKey: (KeyEvent) -> Void

        var body: some View {
            capture($selection)
            return TabView(selection: $selection) {
                Tab("First", value: 0) { Button("Base") {} }
                Tab("Second", value: 1) {
                    Text("Other").sheet(isPresented: $presented) {
                        Text("Modal").focusable().onKeyPress { key in
                            sheetKey(key)
                            return .ignored
                        }
                    }
                }
            }
        }
    }

    private struct AlertTabs: View {
        @State private var selection = 0
        @State private var presented = true
        let cancelled: () -> Void

        var body: some View {
            TabView(selection: $selection) {
                Tab("First", value: 0) { Text("Base") }
                Tab("Second", value: 1) { Button("Other") {} }
                    .alert("Confirm", isPresented: $presented) {
                        Button("Cancel", role: .cancel) { cancelled() }
                    }
            }
        }
    }

    @Test("A dialog wrapping an inactive tab stays hidden and dismisses normally after selection")
    func dialogIsolation() throws {
        // -- Arrange --
        var cancellations = 0
        let renderer = ViewRenderer.make(AlertTabs { cancellations += 1 })
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.arrowRight)
        let dialog = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.escape)
        let dismissed = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(!initial.snapshotText.contains("Confirm"))
        #expect(dialog.snapshotText.contains("Confirm"))
        #expect(!dismissed.snapshotText.contains("Confirm"))
        #expect(dismissed.snapshotText.contains("Other"))
        #expect(cancellations == 1)
    }

    @Test("Inactive sheets stay hidden and active sheets trap tab-switch shortcuts")
    func modalIsolation() throws {
        // -- Arrange --
        var selection: Binding<Int>?
        var modalKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(SheetTabs(capture: { selection = $0 }, sheetKey: { modalKeys.append($0) }))
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.arrowRight)
        let modal = try #require(renderer.render(.now).grid)
        let shortcut = KeyEvent(.pageUp, modifiers: .control)
        let trapped = renderer.handle(shortcut)

        // -- Assert --
        #expect(!initial.snapshotText.contains("Modal"))
        #expect(modal.snapshotText.contains("Modal"))
        #expect(trapped)
        #expect(selection?.wrappedValue == 1)
        #expect(modalKeys == [shortcut])
    }
}
