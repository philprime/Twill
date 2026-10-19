import Foundation

@testable import Twill

/// Each fixture constructs framework views; SVG export only translates the resulting cells.
@MainActor
struct DocumentationPreviewFixture {
    let symbol: String
    let description: String
    let makeRenderer: (MountedTaskRegistry) throws -> ViewRenderer
    var keys: [KeyEvent] = []
    var proposal: ProposedCellSize = .unspecified

    init<Content: View>(
        _ symbol: String, _ description: String,
        keys: [KeyEvent] = [], proposal: ProposedCellSize = .unspecified,
        @ViewBuilder content: @escaping () throws -> Content
    ) {
        self.symbol = symbol
        self.description = description
        self.keys = keys
        self.proposal = proposal
        makeRenderer = { ViewRenderer.make(try content(), taskRegistry: $0) }
    }

    static let date = Date(timeIntervalSinceReferenceDate: 100)

    private static func binding<Value>(_ value: Value) -> Binding<Value> {
        var stored = value
        return Binding(get: { stored }, set: { stored = $0 })
    }

    private struct Row: Identifiable {
        let id: Int
        let name: String
        var children: [Row]?
    }

    private struct FocusExample: View {
        @FocusState var focused: Bool

        var body: some View {
            Button("Continue") {}.focused($focused)
        }
    }

    static var all: [Self] {
        basic + controls + collections + wrappers
    }

}

extension DocumentationPreviewFixture {
    fileprivate static var basic: [Self] {
        [
            Self("Text", "Terminal text, including a wide glyph, with an explicit foreground color.") {
                Text("Hello, terminal 界").foregroundStyle(Color.cyan)
            },
            Self("EmptyView", "Intentionally blank: this view contributes no terminal cells.") { EmptyView() },
            Self("HStack", "Children arranged horizontally with two cells of spacing.") {
                HStack(spacing: 2) {
                    Text("Left")
                    Text("Right")
                }
            },
            Self("VStack", "Children arranged vertically and aligned to the leading edge.") {
                VStack(alignment: .leading) {
                    Text("First row")
                    Text("Second row")
                }
            },
            Self("Group", "Groups content without introducing its own layout; the enclosing stack arranges it.") {
                VStack(alignment: .leading) {
                    Group {
                        Text("Grouped A")
                        Text("Grouped B")
                    }
                }
            },
            Self(
                "ViewList",
                "The view builder creates this heterogeneous child list; its "
                    + "enclosing stack supplies layout."
            ) {
                VStack(alignment: .leading) {
                    Text("Builder child A")
                    Text("Builder child B")
                }
            },
            Self(
                "ConditionalContent",
                "The view builder selects the visible branch while preserving "
                    + "structural identity."
            ) {
                VStack { if true { Text("Visible branch") } else { Text("Other branch") } }
            },
            Self("ForEach", "Repeats keyed content inside a vertical stack.") {
                VStack(alignment: .leading) { ForEach(["Mercury", "Venus", "Earth"], id: \.self) { Text($0) } }
            },
            Self("LazyVGrid", "Two fixed-width columns. The current runtime mounts all children when evaluated.") {
                LazyVGrid(columns: [
                    GridItem(.flexible(minimum: 10, maximum: 10)),
                    GridItem(.flexible(minimum: 10, maximum: 10)),
                ]) {
                    Text("North")
                    Text("East")
                    Text("South")
                    Text("West")
                }
            },
            Self("GroupBox", "A titled rounded border around padded content.") {
                GroupBox("Status") { Text("Ready to connect").padding(1) }
            },
            Self(
                "Canvas", "Cell drawing in an explicit eight-by-three viewport.",
                proposal: .init(width: 8, height: 3)
            ) {
                Canvas { context, _ in
                    for (row, text) in ["╭──────╮", "│ plot │", "╰──────╯"].enumerated() {
                        for (column, character) in text.enumerated() {
                            context.draw(character, column: column, row: row, foreground: .cyan)
                        }
                    }
                }
            },
            Self("PixelCanvas", "A Swift-rasterized RGBA line and circle. Live output requires Kitty graphics.") {
                PixelCanvas(pixelsPerCell: .init(width: 4, height: 4)) { context, _ in
                    let line = Path { path in
                        path.move(to: .init(x: 2, y: 14))
                        path.addLine(to: .init(x: 29, y: 2))
                    }
                    context.stroke(line, with: .init(red: 86, green: 182, blue: 194), lineWidth: 2)
                    context.fill(
                        Path(ellipseIn: PixelRect(x: 11, y: 3, width: 10, height: 10)),
                        with: .init(red: 198, green: 120, blue: 221))
                }.frame(width: 8, height: 4)
            },
            Self(
                "ImageView",
                "A 32-by-16 pixel checkerboard PNG placement, scaled to terminal "
                    + "cells. Live output requires a Kitty graphics "
                    + "compatible terminal such as Ghostty. This SVG embeds the renderer's PNG payload; "
                    + "it does not test "
                    + "terminal decoding or graphics-protocol support."
            ) {
                ImageView(try Image(pngData: imageData), width: 8, height: 4)
            },
            Self(
                "TimelineView",
                "A periodic timeline captured at the fixed reference date, 100 "
                    + "seconds after the epoch."
            ) {
                TimelineView(.periodic(from: date, by: 1)) { context in
                    Text("Tick: \(Int(context.date.timeIntervalSinceReferenceDate))")
                }
            },
        ]
    }

}

extension DocumentationPreviewFixture {
    fileprivate static var controls: [Self] {
        [
            Self("Button", "A focused button. Enter activates it.") { Button("Save changes") {} },
            Self("Toggle", "A checked toggle. Space switches its bound Boolean value.") {
                Toggle("Notifications", isOn: binding(true))
            },
            Self("TextField", "A populated single-line field. Type to edit; arrows move the caret; Enter submits.") {
                TextField("Name", text: binding("Ada"))
            },
            Self(
                "SecureField",
                "A populated password field, masked with bullets. Editing and "
                    + "submission use the original value."
            ) {
                SecureField("Password", text: binding("secret"))
            },
            Self(
                "TextEditor",
                "A multiline editor. Enter inserts a newline; arrows move the "
                    + "caret; Tab switches panes.",
                proposal: .init(width: 24, height: 3)
            ) {
                TextEditor(text: binding("First line\nSecond line"))
            },
            Self(
                "Stepper",
                "An integer adjustment control. Left and Right decrement and "
                    + "increment within its bounds."
            ) {
                Stepper("Copies", value: binding(3), in: 1...9)
            },
            Self("Slider", "A floating-point adjustment control. Left and Right change its value.") {
                Slider("Volume", value: binding(0.6), in: 0...1, step: 0.1)
            },
            Self("Picker", "A horizontal choice control. Left and Right change the selected option.") {
                Picker("Sort", selection: binding("Name"), options: ["Name", "Date", "Size"]) { Text($0) }
            },
            Self("ProgressView", "Determinate progress and an indeterminate spinner, captured at a fixed date.") {
                VStack(alignment: .leading) {
                    ProgressView("Downloading", value: 0.6)
                    ProgressView("Connecting")
                }
            },
            Self(
                "Menu",
                "An open menu, including a shortcut and disabled action. Enter "
                    + "opens or activates; arrows navigate; "
                    + "Escape dismisses.", keys: [.enter]
            ) {
                Menu(
                    "Actions",
                    items: [
                        MenuItem("Save", shortcut: MenuShortcut(.s, hint: "s")) {},
                        MenuItem("Delete", isEnabled: false) {},
                    ])
            },
            Self("DisclosureGroup", "An expanded section. Enter or Space on the header toggles its content.") {
                DisclosureGroup("Details", isExpanded: binding(true)) { Text("Additional information") }
            },
        ]
    }

}

extension DocumentationPreviewFixture {
    fileprivate static var collections: [Self] {
        [
            Self(
                "List",
                "Keyed rows with the first row selected. Up/Down and Home/End "
                    + "change selection; Enter submits."
            ) {
                List(["Inbox", "Drafts", "Sent"], id: \.self, selection: binding(nil as String?)) { Text($0) }
            },
            Self("Table", "Aligned column headers and selected rows. Up/Down and Home/End navigate; Enter submits.") {
                Table(
                    [Row(id: 1, name: "README.md"), Row(id: 2, name: "Package.swift")],
                    selection: binding(nil as Int?)
                ) {
                    TableColumn("File", value: \.name)
                    TableColumn("ID") { Text("\($0.id)") }
                }
            },
            Self(
                "OutlineGroup",
                "An expanded tree. Up/Down navigate visible rows; Right expands "
                    + "or enters; Left collapses "
                    + "or moves to a parent."
            ) {
                OutlineGroup(
                    [
                        Row(id: 1, name: "Sources", children: [Row(id: 2, name: "Twill")]),
                        Row(id: 3, name: "Tests"),
                    ], children: \.children,
                    selection: binding(nil as Int?), expandedIDs: binding(Set([1]))
                ) { Text($0.name) }
            },
            Self(
                "TabView",
                "A selected tab and its destination. Left/Right selects at the "
                    + "bar; Tab or Down enters content; "
                    + "Control-PageUp/Down switches from content."
            ) { tabs },
            Self(
                "Tab",
                "A tab declaration shown inside its required TabView container; "
                    + "the selected destination is visible."
            ) { tabs },
            Self("ScrollView", "Content clipped to a two-row pane. Up/Down scroll; Tab switches panes.") {
                ScrollView {
                    VStack(alignment: .leading) {
                        Text("Visible row 1")
                        Text("Visible row 2")
                        Text("Hidden row 3")
                    }
                }.frame(height: 2)
            },
            Self(
                "ScrollViewReader",
                "Supplies a proxy for programmatic scrolling. The wrapper itself "
                    + "adds no visual treatment."
            ) {
                ScrollViewReader { _ in ScrollView { Text("Scroll target") } }
            },
            Self(
                "Form",
                "Sections group labeled controls, help, and validation. Arrows "
                    + "navigate controls; Enter submits fields."
            ) {
                Form {
                    FormSection("Profile") {
                        FormField("Name", help: "Public display name", validationMessage: "Required") {
                            TextField("Name", text: binding(""))
                        }
                    }
                }
            },
            Self("FormSection", "A section heading groups related fields inside a form.") {
                Form { FormSection("Preferences") { Toggle("Notifications", isOn: binding(true)) } }
            },
            Self("FormField", "A label, editor, help text, and red validation message arranged in reading order.") {
                FormField("Email", help: "Used for receipts", validationMessage: "Enter an address") {
                    TextField("Email", text: binding(""))
                }
            },
        ]
    }

    private static var tabs: some View {
        TabView(selection: binding(0)) {
            Tab("Overview", value: 0) { Text("Project overview") }
            Tab("Settings", value: 1) { Text("Project settings") }
        }
    }

}

extension DocumentationPreviewFixture {
    fileprivate static var wrappers: [Self] {
        [
            Self("BorderView", "The border modifier encloses content in rounded terminal glyphs.") {
                Text("Bordered content").border(.rounded, color: Color.cyan)
            },
            Self("PaddingView", "The padding modifier reserves one blank cell around the enclosed content.") {
                Text("Padded").padding(1)
            },
            Self("FrameView", "The frame modifier centers content in a fixed twenty-by-three cell rectangle.") {
                Text("Centered").frame(width: 20, height: 3)
            },
            Self("StyledView", "Foreground and background modifiers resolve styles into terminal cell colors.") {
                Text("Styled content").foregroundStyle(Color.cyan).backgroundStyle(Color.blue)
            },
            Self(
                "FocusableView",
                "A focusable text target. Reverse video indicates focus; "
                    + "enclosing key handlers define actions."
            ) {
                Text("Keyboard target").focusable()
            },
            Self(
                "FocusedView",
                "Associates a focus binding with a control. The binding adds no "
                    + "visual treatment of its own."
            ) {
                FocusExample()
            },
            Self(
                "KeyPressView",
                "Attaches a key handler to a focusable target; the handler itself "
                    + "adds no visual treatment."
            ) {
                Text("Press a key").focusable().onKeyPress { _ in .handled }
            },
            Self(
                "SubmitView",
                "Attaches submission behavior to the enclosed field without "
                    + "changing its appearance. Enter submits."
            ) {
                TextField("Search", text: binding("Twill")).onSubmit {}
            },
            Self(
                "TaskView",
                "Attaches a mounted asynchronous action. The empty action here "
                    + "leaves the underlying content unchanged."
            ) {
                Text("Task content").task {}
            },
            Self(
                "SheetView",
                "A modal sheet over the base page. It traps keys and focus, "
                    + "restoring focus when dismissed.",
                proposal: .init(width: 28, height: 7)
            ) {
                Text("Base page").sheet(isPresented: binding(true)) {
                    GroupBox("Help") { Button("Close") {}.padding(1) }
                }
            },
        ]
    }

    // A complete PNG, rather than the header-only test images accepted by Image's metadata validation.
    static let imageData = Data(
        base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAACAAAAAQCAIAAAD4YuoOAAAAL0lEQVR4nGMI23YIjv6nMcARtcSpZtAw"
            + "toAWhiKLj1pA2IKhn4qGvgVDPxUNeQsAwo0zLiJrTHEAAAAASUVORK5CYII=")!
}
