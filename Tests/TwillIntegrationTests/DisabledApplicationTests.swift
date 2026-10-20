import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Disabled control application input")
@MainActor
struct DisabledApplicationTests {
    @Test("Disabling the focused control restores editing before the next terminal key", .timeLimit(.minutes(1)))
    func dynamicAvailability() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var saved: [String] = []
        var fallback: [KeyEvent] = []
        let application = Application(
            rootView: AvailabilityFixture(onSave: { saved.append($0) }),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { fallback.append($0) }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    // Enable Save/Clear, save, then clear and disable the focused
                    // control. The next printable key must reach the restored field.
                    try terminal.send([0x61, 0x09, 0x0D, 0x09, 0x0D, 0x62, 0x09, 0x0D, 0x03])
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
        #expect(saved == ["a", "b"])
        #expect(fallback.isEmpty)
        #expect(data.contains(Data("Save".utf8)))
        #expect(try terminal.snapshot() == original)
    }
}

@MainActor
private struct AvailabilityFixture: View {
    @State private var name = ""
    let onSave: @MainActor (String) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Name", text: $name)
            Button("Save") { onSave(name) }.disabled(name.isEmpty)
            Button("Clear") { name = "" }.disabled(name.isEmpty)
        }
    }
}
