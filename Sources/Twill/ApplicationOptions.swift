/// Controls how an application occupies the terminal while it is running.
public enum UIMode: Sendable {
    case fullscreen
    case inline
}

@MainActor
public final class ApplicationOptions {
    public final class UIOptions {
        public var mode: UIMode = .fullscreen

        public init() {}
    }

    // swiftlint:disable:next identifier_name
    public let ui = UIOptions()

    public init() {}
}
