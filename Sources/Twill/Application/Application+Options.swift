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

        public init(ui uiOptions: UIOptions = .init()) {
            self.ui = uiOptions
        }
    }
}
