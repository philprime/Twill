extension Application {
    public struct Options {
        public struct UIOptions {
            /// Controls how an application occupies the terminal while it is running.
            public enum Mode: Sendable {
                case fullscreen
                case inline
            }

            public var mode: Mode

            public init(mode: Mode = .fullscreen) {
                self.mode = mode
            }
        }

        // swiftlint:disable:next identifier_name
        public var ui: UIOptions

        /// Whether Ctrl-C requests orderly shutdown instead of reaching key handlers.
        public var exitOnControlC: Bool

        /// Whether Ctrl-D requests orderly shutdown instead of reaching key handlers.
        public var exitOnControlD: Bool

        public init(ui uiOptions: UIOptions = .init(), exitOnControlC: Bool = true, exitOnControlD: Bool = true) {
            self.ui = uiOptions
            self.exitOnControlC = exitOnControlC
            self.exitOnControlD = exitOnControlD
        }
    }
}
