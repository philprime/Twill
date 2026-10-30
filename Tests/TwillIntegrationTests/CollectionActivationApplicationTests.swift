import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Item activation terminal interaction")
@MainActor
struct CollectionActivationApplicationTests {
    enum Kind: CaseIterable { case list, table, outline }
    private struct Row: Identifiable {
        let id: Int
        let title: String
        var children: [Row]?
    }

    @ViewBuilder
    private func control(
        _ kind: Kind, selection: Binding<Int?>, policy: SelectionPolicy,
        action: @escaping @MainActor (Row) -> Void
    ) -> some View {
        let rows = [Row(id: 1, title: "One"), Row(id: 3, title: "Three")]
        switch kind {
        case .list:
            List(rows, selection: selection, selectionPolicy: policy) { Text($0.title) }.onActivate(action)
        case .table:
            Table(rows, selection: selection, selectionPolicy: policy) { TableColumn("Title", value: \.title) }
                .onActivate(action)
        case .outline:
            OutlineGroup(
                rows, children: \.children, selection: selection, expandedIDs: .constant([]),
                selectionPolicy: policy
            ) { Text($0.title) }.onActivate(action)
        }
    }

    @Test(
        "Enter activates typed effective elements without also submitting", .timeLimit(.minutes(1)),
        arguments: Kind.allCases, [SelectionPolicy.firstVisible, .allowEmpty])
    func activation(kind: Kind, policy: SelectionPolicy) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var selected: Int? = 99
        var activated: [String] = []
        var submitted = 0
        let application = Application(
            rootView: control(
                kind, selection: Binding(get: { selected }, set: { selected = $0 }), policy: policy,
                action: { activated.append($0.title) }
            ).onSubmit { submitted += 1 },
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
        #expect(activated == (policy == .firstVisible ? ["One", "Three"] : ["One"]))
        #expect(selected == (policy == .firstVisible ? 3 : 1))
        #expect(submitted == 0)
        #expect(try terminal.snapshot() == original)
    }
}
