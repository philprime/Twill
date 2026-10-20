@testable import Twill

extension DocumentationPreviewFixture {
    static var paletteFixtures: [Self] {
        [
            Self("CommandPalette", "Search available commands while selection remains independent of search focus.") {
                CommandPalette(
                    commands: [
                        Command("save", title: "Save", shortcuts: [KeyboardShortcut(.controlS)], action: {}),
                        Command("close", title: "Close", shortcuts: [KeyboardShortcut(.controlW)], action: {}),
                    ], dismiss: {}
                ).frame(width: 44)
            }
        ]
    }
}
