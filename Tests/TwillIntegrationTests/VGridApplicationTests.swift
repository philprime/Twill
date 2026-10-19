import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Eager grid terminal interaction")
@MainActor
struct VGridApplicationTests {
    @Test("Eager grid cells retain ordinary traversal and restore terminal modes", .timeLimit(.minutes(1)))
    func gridControls() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var activated: [Int] = []
        let application = Application(
            rootView: VGrid(columns: [GridItem(.fixed(4)), GridItem(.fixed(4))], rowSpacing: 0, columnSpacing: 1) {
                ForEach(1...4, id: \.self) { id in Button("\(id)") { activated.append(id) } }
            },
            runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send(Array("\r\t\r\u{3}".utf8)) } catch {
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
        #expect(activated == [1, 2])
        #expect(try terminal.snapshot() == original)
    }
}
