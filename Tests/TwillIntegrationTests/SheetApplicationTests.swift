import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Modal application input")
@MainActor
struct SheetApplicationTests {
    @Test("A presented sheet traps keys and Ctrl-C restores inherited terminal state", .timeLimit(.minutes(1)))
    func modalInputAndShutdown() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var baseKeys: [KeyEvent] = []
        var sheetKeys: [KeyEvent] = []
        let application = Application(
            rootView: ModalInputFixture(onBase: { baseKeys.append($0) }, onSheet: { sheetKeys.append($0) }),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
            )
        )
        var applicationKeys: [KeyEvent] = []
        application.onKeyEvent = { applicationKeys.append($0) }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([0x6F, 0x78, 0x03]) } catch {
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
        #expect(baseKeys.isEmpty)
        #expect(sheetKeys == [.character("x")])
        #expect(applicationKeys.isEmpty)
        #expect(data.starts(with: Data("\u{1B}[?25l\r\u{1B}[2K\u{1B}[7mBase\u{1B}[27m".utf8)))
        #expect(data.suffix(Data("\n\u{1B}[?25h".utf8).count) == Data("\n\u{1B}[?25h".utf8))
        #expect(try terminal.snapshot() == original)
    }
}

@MainActor
private struct ModalInputFixture: View {
    @State private var presented = false
    let onBase: @MainActor (KeyEvent) -> Void
    let onSheet: @MainActor (KeyEvent) -> Void

    var body: some View {
        Text("Base").focusable().onKeyPress { key in
            if key == .character("o") {
                presented = true
                return .handled
            }
            onBase(key)
            return .ignored
        }
        .sheet(isPresented: $presented) {
            Text("Sheet").focusable().onKeyPress { key in
                onSheet(key)
                return .ignored
            }
        }
    }
}
