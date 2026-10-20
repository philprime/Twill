/// Lifecycle presence is separate from the revocable action scope of payload content.
@MainActor
struct MountedSheetState {
    var current: MountedSheetPresentation?

    mutating func begin(
        identity: AnyHashable?, onDismiss: @escaping @MainActor () -> Void
    ) -> MountedSheetPresentation {
        if let current {
            if current.identity != identity {
                current.identity = identity
                current.actionScope = MountedSheetActionScope()
            }
            current.onDismiss = onDismiss
            return current
        }
        let presentation = MountedSheetPresentation(identity: identity, onDismiss: onDismiss)
        current = presentation
        return presentation
    }

    mutating func end() -> (@MainActor () -> Void)? {
        let callback = current?.onDismiss
        current = nil
        return callback
    }
}

@MainActor
final class MountedSheetActionScope {}

@MainActor
final class MountedSheetPresentation {
    var identity: AnyHashable?
    var actionScope = MountedSheetActionScope()
    var onDismiss: @MainActor () -> Void

    init(identity: AnyHashable?, onDismiss: @escaping @MainActor () -> Void) {
        self.identity = identity
        self.onDismiss = onDismiss
    }
}
