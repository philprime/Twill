import Foundation
import Testing

@testable import Twill

@Suite("Form composition")
@MainActor
struct FormTests {
    private struct EditableForm: View {
        @State private var name = ""

        var body: some View {
            Form {
                FormSection("Profile") {
                    FormField("Name", help: "Public name", validationMessage: name.isEmpty ? "Required" : nil) {
                        TextField("Name", text: $name)
                    }
                }
                FormField("Action") { Button("Save") {} }
            }
        }
    }

    @Test("Editing removes validation without remounting the field or resetting its caret")
    func validationUpdate() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(EditableForm())
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.a)
        let valid = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.b)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.render(.now)
        _ = renderer.handle(.c)
        let edited = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowDown)
        let retained = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(initial.snapshotText.contains("Required"))
        #expect(!valid.snapshotText.contains("Required"))
        #expect(edited.snapshotText.contains("acb"))
        #expect(edited.isFocused(column: 0, row: 2))
        #expect(retained.isFocused(column: 0, row: 2))
    }

    @Test("Form controls use enclosing pane traversal and submission")
    func paneTraversal() {
        // -- Arrange --
        var name = ""
        var submissions: [String] = []
        var saves = 0
        let renderer = ViewRenderer.make(
            HStack {
                ScrollView {
                    Form {
                        FormSection("Profile") {
                            FormField("Name", help: "Public name") {
                                TextField("Name", text: Binding(get: { name }, set: { name = $0 }))
                            }
                        }
                    }
                    .onSubmit { submissions.append(name) }
                }.frame(height: 4)
                ScrollView {
                    Form { FormField("Action") { Button("Save") { saves += 1 } } }
                }.frame(height: 2)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.a)
        _ = renderer.render(.now)
        let submitted = renderer.handle(.enter)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.shiftTab)
        _ = renderer.handle(.b)

        // -- Assert --
        #expect(submitted)
        #expect(submissions == ["a"])
        #expect(saves == 1)
        #expect(name == "ab")
    }

    @Test("Arrow navigation skips section headings, labels, help, and validation")
    func skipsStaticContent() {
        // -- Arrange --
        var actions: [String] = []
        let renderer = ViewRenderer.make(
            Form {
                FormSection("Actions") {
                    FormField("First", help: "Help", validationMessage: "Warning") {
                        Button("One") { actions.append("one") }
                    }
                    FormField("Second") { Button("Two") { actions.append("two") } }
                }
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.arrowUp)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(actions == ["one", "two", "one"])
    }

    @Test("Empty forms occupy no cells")
    func emptyForm() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Form {})

        // -- Act --
        let result = renderer.render(.now)

        // -- Assert --
        #expect(result.grid == nil || result.grid?.size == CellSize(width: 0, height: 0))
        #expect(result.nextUpdate == nil)
    }

    @Test("Sections and fields group labels, controls, help, and validation in reading order")
    func groupedFields() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Form {
                FormSection("Profile") {
                    FormField("Name", help: "Public name", validationMessage: "Required") {
                        Text("[name]")
                    }
                    FormField("Email") { Text("[email]") }
                }
                FormSection("Options") {
                    FormField("Theme") { Text("Dark") }
                }
            })

        // -- Act --
        let snapshot = renderer.render(.now)
        let frame = try #require(snapshot.grid)
        let rows = frame.snapshotText.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // -- Assert --
        #expect(
            rows == [
                "Profile", "Name", "[name]", "Public name", "Required", "", "Email", "[email]",
                "", "Options", "Theme", "Dark",
            ])
        #expect(frame.foreground(column: 0, row: 4) == Color.red)
        #expect(!frame.isFocused(column: 0, row: 0))
        #expect(snapshot.nextUpdate == nil)
    }
}
