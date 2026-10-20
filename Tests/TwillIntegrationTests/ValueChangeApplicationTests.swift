import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Value observation terminal interaction")
@MainActor
struct ValueChangeApplicationTests {
    private struct Fixture: View {
        @State private var enabled = false
        let callback: @MainActor (String) -> Void
        var body: some View {
            VStack {
                Toggle("Flag", isOn: $enabled)
                Button("Next") { callback("next") }
            }.onChange(of: enabled) { callback("\($0):\($1)") }
        }
    }

    @Test("Binding changes deliver at update boundaries and inherited terminal modes restore", .timeLimit(.minutes(1)))
    func changes() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var events: [String] = []
        let application = Application(
            rootView: Fixture(callback: { events.append($0) }), runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send(Array(" \t\r\u{1B}[Z \t\u{3}".utf8)) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        _ = try pipe.fileHandleForReading.readToEnd()
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(events == ["false:true", "next", "true:false"])
        #expect(try terminal.snapshot() == original)
    }
}
