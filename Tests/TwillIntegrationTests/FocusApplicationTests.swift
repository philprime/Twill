import Foundation
import Testing
import Twill

@Suite("Focused application input")
@MainActor
struct FocusApplicationTests {
    @Test("Arrow navigation updates selection while leaving focus movement to the runtime", .timeLimit(.minutes(1)))
    func selectionFollowsFocus() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var selected: [String] = []
        var activated: [String] = []
        let application = Application(
            rootView: NoteSelectionFixture(
                onSelect: { selected.append($0) }, onActivate: { activated.append($0) }),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
            )
        )
        application.options.ui.mode = .inline
        var applicationKeys: [KeyEvent] = []
        application.onKeyEvent = { [weak application] key in
            applicationKeys.append(key)
            if key == .q { application?.stop() }
        }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    try terminal.send([
                        0x1B, 0x5B, 0x42, 0x1B, 0x5B, 0x42,
                        0x1B, 0x5B, 0x41, 0x1B, 0x5B, 0x42, 0x0D, 0x71,
                    ])
                } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        let output = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(selected == ["Groceries", "Weekend", "Groceries", "Weekend", "Weekend"])
        #expect(activated == ["Weekend"])
        #expect(applicationKeys == [.q])
        #expect(output.contains(Data("Detail: Groceries".utf8)))
        #expect(try terminal.snapshot() == original)
    }

    @Test("Arrow input moves between focused controls before application fallback", .timeLimit(.minutes(1)))
    func focusedInput() async throws {
        weak var owner: Application?
        do {
            // -- Arrange --
            let terminal = try TestTerminal()
            let original = try terminal.snapshot()
            let pipe = Pipe()
            let runLoop = DefaultRunLoop()
            var activated: [String] = []
            let root = HStack {
                Text("One").focusable().onKeyPress { key in
                    guard key == .enter else { return .ignored }
                    activated.append("One")
                    return .handled
                }
                Text("Two").focusable().onKeyPress { key in
                    guard key == .enter else { return .ignored }
                    activated.append("Two")
                    return .handled
                }
            }
            let application = Application(
                rootView: root, runLoop: runLoop,
                terminalSession: DefaultTerminalSession(
                    fileDescriptor: .custom(terminal.fileDescriptor),
                    output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
                )
            )
            application.options.ui.mode = .inline
            owner = application
            var applicationKeys: [KeyEvent] = []
            application.onKeyEvent = { [weak application] key in
                applicationKeys.append(key)
                if key == .q { application?.stop() }
            }
            runLoop.add(
                Twill.Timer(interval: .milliseconds(1)) {
                    do { try terminal.send([0x0D, 0x1B, 0x5B, 0x42, 0x0D, 0x71]) } catch {
                        Issue.record(error)
                        application.stop()
                    }
                })

            // -- Act --
            try await application.run()
            try pipe.fileHandleForWriting.close()
            let data = try #require(try pipe.fileHandleForReading.readToEnd())
            try pipe.fileHandleForReading.close()

            // -- Assert --
            #expect(activated == ["One", "Two"])
            #expect(applicationKeys == [.q])
            #expect(data.starts(with: Data("\u{1B}[?25l\r\u{1B}[2K\u{1B}[7mOne\u{1B}[27m Two".utf8)))
            #expect(try terminal.snapshot() == original)
        }
        #expect(owner == nil)
    }
}

@MainActor
private struct NoteSelectionFixture: View {
    private struct Item: Identifiable {
        let id: String
        let title: String
    }

    private let items = [
        Item(id: "groceries", title: "Groceries"),
        Item(id: "weekend", title: "Weekend"),
    ]
    @State private var selected = "Groceries"
    @State private var query = ""
    let onSelect: @MainActor (String) -> Void
    let onActivate: @MainActor (String) -> Void

    var body: some View {
        VStack {
            TextField("Search", text: $query)
                .onKeyPress { key in
                    if key == .arrowDown || key == .arrowRight {
                        selected = items[0].title
                        onSelect(selected)
                    }
                    return .ignored
                }
            ForEach(items) { item in
                Text(item.title)
                    .focusable()
                    .onKeyPress { key in
                        if key == .enter {
                            selected = item.title
                            onSelect(item.title)
                            onActivate(item.title)
                            return .handled
                        }
                        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return .ignored }
                        switch key {
                        case .arrowDown, .arrowRight:
                            if items.indices.contains(index + 1) {
                                selected = items[index + 1].title
                                onSelect(selected)
                            }
                        case .arrowUp, .arrowLeft:
                            if items.indices.contains(index - 1) {
                                selected = items[index - 1].title
                                onSelect(selected)
                            }
                        default: break
                        }
                        return .ignored
                    }
            }
            Text("Detail: \(selected)")
        }
    }
}
