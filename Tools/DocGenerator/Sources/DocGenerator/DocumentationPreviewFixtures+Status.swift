@testable import Twill

extension DocumentationPreviewFixture {
    static var statusFixtures: [Self] {
        [
            Self("ContentUnavailableView", "Caller-owned empty content with an ordinary retry action.") {
                ContentUnavailableView {
                    Text("No results")
                } description: {
                    Text("Try another search")
                } actions: {
                    Button("Retry") {}
                }.frame(width: 24, height: 7)
            },
            Self("StatusBar", "A one-cell status row composing ordinary key hints and flexible space.") {
                StatusBar {
                    Text("Ready")
                    Spacer()
                    KeyHints([Command("save", title: "Save", shortcuts: [KeyboardShortcut(.s)], action: {})])
                }.frame(width: 28)
            },
        ]
    }
}
