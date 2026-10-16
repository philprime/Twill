import Foundation
import Testing

@testable import Twill

@Suite("Alerts and confirmation dialogs")
@MainActor
struct AlertTests {
    @MainActor private final class Model {
        var presented = true
        var actions: [String] = []
        var binding: Binding<Bool> { Binding(get: { self.presented }, set: { self.presented = $0 }) }
    }

    @Test("Alerts render their title, message and labeled actions without scheduling work")
    func presentation() throws {
        // -- Arrange --
        let model = Model()
        let renderer = ViewRenderer.make(
            Text("Base").alert("Failure", isPresented: model.binding) {
                Button("Retry") { model.actions.append("retry") }
            } message: {
                Text("Please try again")
            })

        // -- Act --
        let frame = renderer.render(.now)
        let text = try #require(frame.grid?.snapshotText)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(text.contains("Failure"))
        #expect(text.contains("Please try again"))
        #expect(text.contains("Retry"))
        #expect(!text.contains("Cancel"))
        #expect(frame.nextUpdate == nil)
        #expect(model.actions == ["retry"])
        #expect(!model.presented)
    }

    @Test("An alert without actions supplies an OK button")
    func defaultAcknowledgement() throws {
        // -- Arrange --
        let model = Model()
        let renderer = ViewRenderer.make(Text("Base").alert("Notice", isPresented: model.binding) {})

        // -- Act --
        let frame = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        let text = try #require(frame.grid?.snapshotText)
        #expect(text.contains("OK"))
        #expect(!model.presented)
    }

    @Test("Escape invokes the cancel action once and dismisses after it runs")
    func cancellation() {
        // -- Arrange --
        let model = Model()
        let renderer = ViewRenderer.make(
            Text("Base").alert("Delete?", isPresented: model.binding) {
                Button("Delete", role: .destructive) { model.actions.append("delete") }
                Button("Keep", role: .cancel) { model.actions.append(model.presented ? "cancel" : "already dismissed") }
            })
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.escape)
        _ = renderer.handle(.escape)

        // -- Assert --
        #expect(handled)
        #expect(model.actions == ["cancel"])
        #expect(!model.presented)
    }

    @Test("Escape without a cancel action dismisses without performing another action")
    func implicitCancellation() {
        // -- Arrange --
        let model = Model()
        let renderer = ViewRenderer.make(
            Text("Base").alert("Failure", isPresented: model.binding) {
                Button("Retry") { model.actions.append("retry") }
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.escape)

        // -- Assert --
        #expect(!model.presented)
        #expect(model.actions.isEmpty)
    }

    @Test("Confirmation dialogs supply a cancel action and focus it instead of destructive actions")
    func safeConfirmation() throws {
        // -- Arrange --
        let model = Model()
        let renderer = ViewRenderer.make(
            Text("Base").confirmationDialog("Delete?", isPresented: model.binding) {
                Button("Delete", role: .destructive) { model.actions.append("delete") }
            } message: {
                Text("Cannot undo")
            })

        // -- Act --
        let frame = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        let text = try #require(frame.grid?.snapshotText)
        #expect(text.contains("Cannot undo"))
        #expect(text.contains("Cancel"))
        #expect(model.actions.isEmpty)
        #expect(!model.presented)
    }

    @Test("An explicit cancel replaces the default and destructive actions require deliberate navigation")
    func explicitActions() throws {
        // -- Arrange --
        let model = Model()
        let renderer = ViewRenderer.make(
            Text("Base").confirmationDialog("Delete?", isPresented: model.binding) {
                Button("Delete", role: .destructive) { model.actions.append("delete") }
                Button("Keep", role: .cancel) { model.actions.append("keep") }
            })
        let frame = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowUp)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(!(try #require(frame.grid?.snapshotText)).contains("Cancel"))
        #expect(model.actions == ["delete"])
        #expect(!model.presented)
    }

    @Test("Dialogs trap keys and restore focus before the next input", arguments: [false, true])
    func focusRestoration(confirmation: Bool) throws {
        // -- Arrange --
        let model = Model()
        let host = ViewHost(
            rootView: DialogFixture(confirmation: confirmation, record: { model.actions.append($0) }),
            runLoop: RecordingRunLoop(), output: RecordingTerminalOutput())
        try host.start()
        defer { host.stop() }

        // -- Act --
        _ = host.handle(.arrowRight)
        _ = host.handle(.enter)
        let trapped = host.handle(.x)
        _ = host.handle(.escape)
        _ = host.handle(.enter)
        _ = host.handle(.arrowUp)
        _ = host.handle(.enter)
        _ = host.handle(.enter)

        // -- Assert --
        #expect(trapped)
        #expect(model.actions == ["open", "cancel", "open", "delete", "open"])
    }

    @Test("Hidden dialog builders are not evaluated")
    func hiddenContent() {
        // -- Arrange --
        let model = Model()
        model.presented = false
        let renderer = ViewRenderer.make(
            Text("Base").alert("Failure", isPresented: model.binding) {
                model.actions.append("evaluated")
                return Button("OK") {}
            })

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "Base")
        #expect(model.actions.isEmpty)
    }

    @Test("Parent updates retain the default cancel button and its focus")
    func fallbackRetention() {
        // -- Arrange --
        let model = Model()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { _ in
                Text("Base").confirmationDialog("Delete?", isPresented: model.binding) {
                    Button("Delete", role: .destructive) { model.actions.append("delete") }
                }
            })
        _ = renderer.render(start)

        // -- Act --
        _ = renderer.render(start.addingTimeInterval(1))
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(model.actions.isEmpty)
        #expect(!model.presented)
    }

    @Test("Independently updating actions keep automatic cancellation in sync", arguments: [false, true])
    func changingActions(addsCancel: Bool) throws {
        // -- Arrange --
        let model = Model()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            Text("Base").confirmationDialog("Choose", isPresented: model.binding) {
                TimelineView(.periodic(from: start, by: 1)) { context in
                    Group {
                        Button("Proceed") { model.actions.append("proceed") }
                        if (context.date > start) == addsCancel {
                            Button("Keep", role: .cancel) { model.actions.append("keep") }
                        }
                    }
                }
            })
        _ = renderer.render(start)

        // -- Act --
        let frame = renderer.render(start.addingTimeInterval(1))
        _ = renderer.handle(.escape)

        // -- Assert --
        let text = try #require(frame.grid?.snapshotText)
        #expect(text.contains("Keep") == addsCancel)
        #expect(text.contains("Cancel") == !addsCancel)
        #expect(model.actions == (addsCancel ? ["keep"] : []))
    }

    @Test("Destructive buttons are distinguished visually")
    func destructiveAppearance() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Button("Delete", role: .destructive) {})

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.foreground(column: 0, row: 0) == .red)
    }
}

@MainActor
private struct DialogFixture: View {
    @State private var presented = false
    let confirmation: Bool
    let record: @MainActor (String) -> Void

    private var base: some View {
        HStack {
            Button("Other") { record("other") }
            Button("Open") {
                record("open")
                presented = true
            }
        }
        .onKeyPress { key in
            guard key == .x else { return .ignored }
            record("leaked")
            return .handled
        }
    }

    private var actions: some View {
        Group {
            Button("Delete", role: .destructive) { record("delete") }
            Button("Keep", role: .cancel) { record("cancel") }
        }
    }

    @ViewBuilder var body: some View {
        if confirmation {
            base.confirmationDialog("Delete?", isPresented: $presented) { actions }
        } else {
            base.alert("Delete?", isPresented: $presented) { actions }
        }
    }
}
