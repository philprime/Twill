import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Disclosure group application input")
@MainActor
struct DisclosureGroupApplicationTests {
    @Test(
        "Real input collapses focused content safely and restores terminal state", .timeLimit(.minutes(1)),
        arguments: [false, true])
    func disclosureInput(cancel: Bool) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        let (ready, continuation) = AsyncStream<Void>.makeStream()
        var snapshots: [String] = []
        var events: [String] = []
        var leakedKeys: [KeyEvent] = []
        let application = Application(
            rootView: DisclosureInputFixture(
                record: { snapshots.append($0) },
                activate: {
                    events.append($0)
                    continuation.yield(())
                    continuation.finish()
                }),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { leakedKeys.append($0) }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    try terminal.send([
                        0x1B, 0x5B, 0x42, 0x1B, 0x5B, 0x42, 0x78, 0x1B, 0x0D,
                        0x1B, 0x5B, 0x42, 0x79, 0x1B, 0x1B, 0x5B, 0x42, 0x0D,
                    ])
                } catch {
                    Issue.record(error)
                    continuation.finish()
                }
            })
        let task = Task { try await application.run() }
        defer { task.cancel() }
        for await _ in ready {}

        // -- Act --
        if cancel { task.cancel() } else { application.stop() }
        try await task.value
        try pipe.fileHandleForWriting.close()
        let data = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(snapshots == ["x", "xy"])
        #expect(events == ["after"])
        #expect(leakedKeys.isEmpty)
        let restoredCursor = Data("\n\u{1B}[?25h".utf8)
        #expect(data.suffix(restoredCursor.count) == restoredCursor)
        #expect(try terminal.snapshot() == original)
    }
}

@MainActor
private struct DisclosureInputFixture: View {
    @State private var expanded = true
    @State private var text = ""
    let record: @MainActor (String) -> Void
    let activate: @MainActor (String) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Button("Before") { activate("before") }
            DisclosureGroup("Details", isExpanded: $expanded) {
                TextField("Value", text: $text)
            }
            Button("After") { activate("after") }
        }
        .onKeyPress { key in
            guard key == .escape else { return .ignored }
            record(text)
            expanded = false
            return .handled
        }
    }
}
