import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Nested menu terminal interaction")
@MainActor
struct NestedMenuApplicationTests {
    @Test(
        "Submenu actions isolate shortcuts and restore focus and inherited terminal settings", .timeLimit(.minutes(1)))
    func scopedActions() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var actions: [String] = []
        let application = Application(
            rootView: HStack {
                Button("Before") { actions.append("before") }
                Menu("Root") {
                    Menu("More") { Button("Leaf") { actions.append("leaf") }.keyboardShortcut(.l) }
                    Divider()
                    Button("Parent") { actions.append("parent") }.keyboardShortcut(.p)
                }
            }, runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send(Array("\t\r\u{1B}[Cpl\r\u{1B}[C\u{1B}[D\u{1B}\u{3}".utf8)) } catch {
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
        #expect(actions == ["leaf"])
        #expect(try terminal.snapshot() == original)
    }
}
