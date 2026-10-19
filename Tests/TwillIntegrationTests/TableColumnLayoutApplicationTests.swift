import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Sized table terminal presentation")
@MainActor
struct TableColumnLayoutApplicationTests {
    private struct Row: Identifiable {
        let id = 1
        let name = "A"
        let count = 12
    }

    @Test("Column geometry preserves activation and inherited terminal cleanup", .timeLimit(.minutes(1)))
    func sizedTable() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var activated: [Int] = []
        let application = Application(
            rootView: Table([Row()], selection: .constant(nil)) {
                TableColumn("Name", value: \.name).width(4)
                TableColumn("N") { Text("\($0.count)") }.width(4).alignment(.trailing)
            }.onActivate { activated.append($0.id) },
            runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send([0x0D, 0x03]) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        let data = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()
        let output = try #require(String(data: data, encoding: .utf8))

        // -- Assert --
        #expect(output.contains("Name     N"))
        #expect(activated == [1])
        #expect(try terminal.snapshot() == original)
    }
}
