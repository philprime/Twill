/// The hint renderer needs presentation data, not command identity or action closures.
struct KeyHintDescription {
    let title: String
    let isEnabled: Bool
    let shortcuts: [KeyboardShortcut]

    var hasContent: Bool { isEnabled && !shortcuts.isEmpty }

    var text: String? {
        guard hasContent else { return nil }
        return shortcuts.map(\.hint).joined(separator: "/") + ": " + title
    }
}
