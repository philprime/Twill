extension Application {
    /// Presentation and lifecycle shortcut settings for an application.
    public struct Options {
        /// Settings that control terminal presentation.
        public struct UIOptions {
            /// Controls how an application occupies the terminal while it is running.
            public enum Mode: Sendable {
                /// Uses the alternate screen for the application and restores the previous screen on exit.
                case fullscreen
                /// Presents within the current terminal screen without entering the alternate screen.
                case inline
            }

            /// How the application occupies the terminal.
            public var mode: Mode

            /// Immutable capabilities applied to the mounted tree at session start.
            public var terminalCapabilities: TerminalCapabilities

            /// Creates presentation settings, using fullscreen mode by default.
            public init(mode: Mode = .fullscreen, terminalCapabilities: TerminalCapabilities = .detect()) {
                self.mode = mode
                self.terminalCapabilities = terminalCapabilities
            }
        }

        // swiftlint:disable identifier_name
        /// The terminal presentation settings applied when the application runs.
        public var ui: UIOptions
        // swiftlint:enable identifier_name

        /// Whether Ctrl-C requests orderly shutdown instead of reaching key handlers.
        public var exitOnControlC: Bool

        /// Whether Ctrl-D requests orderly shutdown instead of reaching key handlers.
        public var exitOnControlD: Bool

        /// Creates application settings with presentation and orderly-shutdown shortcut policies.
        public init(ui uiOptions: UIOptions = .init(), exitOnControlC: Bool = true, exitOnControlD: Bool = true) {
            self.ui = uiOptions
            self.exitOnControlC = exitOnControlC
            self.exitOnControlD = exitOnControlD
        }
    }
}
