/// Displays the shortcuts and titles of currently available commands.
/// Commands without shortcuts are omitted. This view does not register actions.
public struct KeyHints<ID: Hashable>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let commands: [Command<ID>]

    /// Creates help text from the same command snapshots used by controls.
    public init(_ commands: [Command<ID>]) {
        self.commands = commands
    }
}

extension KeyHints: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .keyHints(
            commands.map { KeyHintDescription(title: $0.title, isEnabled: $0.isEnabled, shortcuts: $0.shortcuts) })
    }
}
