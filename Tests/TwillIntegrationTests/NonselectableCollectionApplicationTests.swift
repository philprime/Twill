import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Nonselectable collection terminal interaction")
@MainActor
struct NonselectableCollectionApplicationTests {
    enum Kind: CaseIterable { case list, table }
    private struct Entry {
        let key: Int
        let name: String
    }

    @ViewBuilder
    private func collection(
        _ kind: Kind, rowAction: @escaping @MainActor (Int) -> Void, collectionAction: @escaping @MainActor () -> Void
    ) -> some View {
        let entries = [Entry(key: 1, name: "One"), Entry(key: 2, name: "Two")]
        switch kind {
        case .list:
            List(entries, id: \.key) { entry in Button(entry.name) { rowAction(entry.key) } }
                .onActivate { _ in collectionAction() }
        case .table:
            Table(entries, id: \.key) {
                TableColumn("Name") { entry in Button(entry.name) { rowAction(entry.key) } }
            }.onActivate { _ in collectionAction() }
        }
    }

    @Test(
        "Tab visits row controls without adding collection activation", .timeLimit(.minutes(1)),
        arguments: Kind.allCases)
    func rowControls(kind: Kind) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var rows: [Int] = []
        var collectionCalls = 0
        var submitted = 0
        let application = Application(
            rootView: collection(kind, rowAction: { rows.append($0) }, collectionAction: { collectionCalls += 1 })
                .onSubmit { submitted += 1 },
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
        #expect(rows == [1, 2])
        #expect(collectionCalls == 0 && submitted == 0)
        #expect(try terminal.snapshot() == original)
    }
}
