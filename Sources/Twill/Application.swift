/// Owns the serialized TUI application lifecycle.
@MainActor
public final class Application {
    private let runLoop: RunLoop

    public init(runLoop: RunLoop) {
        self.runLoop = runLoop
    }

    /// Runs the application until its task is cancelled.
    public func run() async {
        await runLoop.run()
    }
}
