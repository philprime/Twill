import Foundation
import Testing
import Twill

@Suite("Table application input")
@MainActor
struct TableApplicationTests {
    private struct Item: Identifiable {
        let id: Int
        let name: String
        let count: Int
    }

    @Test("Table headers and selection handle terminal input and restore inherited modes", .timeLimit(.minutes(1)))
    func sortingAndSelection() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        let items = [Item(id: 0, name: "Alpha", count: 2), Item(id: 1, name: "Beta", count: 1)]
        var selection: Int? = 0
        var sortOrder: [KeyPathComparator<Item>] = []
        var activated: [Int?] = []
        var applicationKeys: [KeyEvent] = []
        let application = Application(
            rootView: Table(
                items, selection: Binding(get: { selection }, set: { selection = $0 }),
                sortOrder: Binding(get: { sortOrder }, set: { sortOrder = $0 })
            ) {
                TableColumn("Name", value: \.name)
                TableColumn("Count", value: \.count) { Text("\($0.count)") }
            }
            .frame(height: 2)
            .onSubmit { activated.append(selection) },
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { [weak application] key in
            applicationKeys.append(key)
            if key == .q { application?.stop() }
        }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    // Sort Name, move right and sort Count, enter rows, select Beta, submit, quit.
                    try terminal.send(Array("\r\u{1B}[C\r\u{1B}[B\u{1B}[B\rq".utf8))
                } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        let output = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(selection == 1)
        #expect(sortOrder.map(\.keyPath) == [\Item.count, \Item.name])
        #expect(sortOrder.first?.order == .forward)
        #expect(activated == [1])
        #expect(applicationKeys == [.q])
        #expect(output.contains(Data("Name".utf8)))
        #expect(try terminal.snapshot() == original)
    }
}
