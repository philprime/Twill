/// Action metadata is erased only when a concrete button reaches the mounted runtime.
struct ButtonDescription {
    let content: any View
    let role: ButtonRole?
    let action: @MainActor () -> Void
    let isEnabled: Bool
    let shortcuts: [KeyboardShortcut]
}
