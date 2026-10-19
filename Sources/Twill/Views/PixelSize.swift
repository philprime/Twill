/// Nonnegative bitmap dimensions, measured in pixels rather than terminal cells.
public struct PixelSize: Sendable, Equatable {
    /// The number of pixel columns.
    public let width: Int
    /// The number of pixel rows.
    public let height: Int

    /// Creates dimensions whose RGBA storage fits in an integer.
    public init(width: Int, height: Int) {
        precondition(width >= 0 && height >= 0)
        let area = width.multipliedReportingOverflow(by: height)
        precondition(!area.overflow && area.partialValue <= Int.max / 4)
        self.width = width
        self.height = height
    }
}
