import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Cell indicator terminal interaction")
@MainActor
struct ScrollIndicatorApplicationTests {
    @Test("Indicator cells preserve paging focus and terminal restoration", .timeLimit(.minutes(1)))
    func indicatorViewport() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var activated: [Int] = []
        let application = Application(
            rootView: ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<6, id: \.self) { id in Button("\(id)") { activated.append(id) } }
                }
            }.scrollIndicators(.visible).frame(width: 3, height: 3),
            runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send(Array("\u{1B}[6~\r\u{3}".utf8)) } catch {
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
        #expect(output.contains("█") && output.contains("│"))
        #expect(activated == [0])
        #expect(try terminal.snapshot() == original)
    }
}
