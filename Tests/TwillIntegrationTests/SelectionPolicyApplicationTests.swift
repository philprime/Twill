import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Selection policy terminal interaction")
@MainActor
struct SelectionPolicyApplicationTests {
    enum Kind: CaseIterable { case list, table, outline }
    private struct Row: Identifiable {
        let id: Int
        var children: [Row]?
    }

    @ViewBuilder
    private func control(_ kind: Kind, selection: Binding<Int?>) -> some View {
        let rows = [Row(id: 1), Row(id: 3)]
        switch kind {
        case .list:
            List(rows, selection: selection, selectionPolicy: .allowEmpty) { Text("\($0.id)") }
        case .table:
            Table(rows, selection: selection, selectionPolicy: .allowEmpty) { TableColumn("ID") { Text("\($0.id)") } }
        case .outline:
            OutlineGroup(
                rows, children: \.children, selection: selection, expandedIDs: .constant([]),
                selectionPolicy: .allowEmpty
            ) { Text("\($0.id)") }
        }
    }

    @Test(
        "No-selection Enter is consumed and explicit navigation enables submission", .timeLimit(.minutes(1)),
        arguments: Kind.allCases)
    func selection(kind: Kind) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var selected: Int?
        var writes: [Int?] = []
        var submitted: [Int?] = []
        let application = Application(
            rootView: control(
                kind,
                selection: Binding(
                    get: { selected },
                    set: {
                        selected = $0
                        writes.append($0)
                    })
            )
            .onSubmit { submitted.append(selected) },
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
        _ = try pipe.fileHandleForReading.readToEnd()
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(selected == 1)
        #expect(writes == [1, 1])
        #expect(submitted == [1])
        #expect(try terminal.snapshot() == original)
    }
}
