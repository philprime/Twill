import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Formatted table terminal interaction")
@MainActor
struct FormattedTableApplicationTests {
    private struct Row: Identifiable {
        let id: Int
        let value: Int
    }

    @Test("Formatting leaves numeric sorting and caller-owned activation order intact", .timeLimit(.minutes(1)))
    func formattedSorting() async throws {
        // -- Arrange --
        let rows = [Row(id: 1, value: 10), Row(id: 2, value: 2)]
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var order: [KeyPathComparator<Row>] = []
        var activated: [Int] = []
        let application = Application(
            rootView: Table(rows, selection: .constant(nil), sortOrder: Binding(get: { order }, set: { order = $0 })) {
                TableColumn("Count", value: \.value, format: { "\($0) units" }).width(10)
            }.onActivate { activated.append($0.value) },
            runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send(Array("\r\u{1B}[B\r\u{3}".utf8)) } catch {
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
        #expect(output.contains("10 units"))
        #expect(order.first?.compare(rows[0], rows[1]) == .orderedDescending)
        #expect(activated == [10])
        #expect(try terminal.snapshot() == original)
    }
}
