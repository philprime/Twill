import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Outline group application input")
@MainActor
struct OutlineGroupApplicationTests {
    @Test("Real terminal navigation expands, collapses, selects and switches panes", .timeLimit(.minutes(1)))
    func hierarchyInput() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var events: [String] = []
        var leakedKeys: [KeyEvent] = []
        let application = Application(
            rootView: OutlineInputFixture { events.append($0) }, runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { leakedKeys.append($0) }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    try terminal.send([
                        0x1B, 0x5B, 0x43, 0x1B, 0x5B, 0x43, 0x1B, 0x5B, 0x43, 0x1B, 0x5B, 0x43,
                        0x0D, 0x1B, 0x5B, 0x44, 0x1B, 0x5B, 0x44, 0x1B, 0x5B, 0x44, 0x1B, 0x5B, 0x44,
                        0x1B, 0x5B, 0x42, 0x0D, 0x09, 0x0D, 0x1B, 0x5B, 0x5A, 0x1B, 0x5B, 0x48, 0x0D, 0x03,
                    ])
                } catch {
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
        #expect(events == ["select:3", "select:5", "other", "select:1"])
        #expect(leakedKeys.isEmpty)
        let restoredCursor = Data("\n\u{1B}[?25h".utf8)
        #expect(data.suffix(restoredCursor.count) == restoredCursor)
        #expect(try terminal.snapshot() == original)
    }
}

@MainActor
private struct OutlineInputFixture: View {
    private struct Node: Identifiable {
        let id: Int
        var children: [Node]?
    }

    @State private var selection: Int?
    @State private var expandedIDs: Set<Int> = []
    let record: @MainActor (String) -> Void

    var body: some View {
        HStack {
            OutlineGroup(
                [Node(id: 1, children: [Node(id: 2, children: [Node(id: 3)])]), Node(id: 5)],
                children: \.children, selection: $selection, expandedIDs: $expandedIDs
            ) { Text("Node \($0.id)") }
            .frame(width: 20, height: 2)
            .onSubmit { record("select:\(selection ?? -1)") }
            ScrollView { Button("Other") { record("other") } }
        }
    }
}
