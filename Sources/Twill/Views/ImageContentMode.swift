/// How pixels occupy an image view's terminal-cell rectangle.
public enum ImageContentMode: Sendable {
    /// Fits and centers the image using the terminal's explicit cell aspect assumption.
    case aspectFit
    /// Scales independently to fill the requested cell rectangle.
    case stretch
}
