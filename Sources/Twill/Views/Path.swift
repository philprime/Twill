/// A reusable value describing straight-line contours and ellipses.
/// Coordinates are independent of a canvas. Filling implicitly closes open
/// contours using the nonzero winding rule; stroking closes only explicit closures.
public struct Path: Sendable, Equatable {
    enum Element: Sendable, Equatable {
        case move(PixelPoint)
        case line(PixelPoint)
        case close
        case ellipse(PixelRect)
    }

    var elements: [Element] = []

    /// Creates an empty path.
    public init() {}

    /// Builds a path by modifying a fresh, independent value.
    public init(_ build: (inout Path) -> Void) {
        self.init()
        build(&self)
    }

    /// Creates a closed rectangular contour.
    public init(_ rectangle: PixelRect) {
        self.init()
        addRect(rectangle)
    }

    /// Creates a closed elliptical contour inscribed in the rectangle.
    public init(ellipseIn rectangle: PixelRect) {
        self.init()
        addEllipse(in: rectangle)
    }

    /// Starts a new contour without connecting it to the preceding one.
    public mutating func move(to point: PixelPoint) {
        precondition(point.horizontal.isFinite && point.vertical.isFinite)
        elements.append(.move(point))
    }

    /// Adds a straight segment. With no current point, starts a contour at this point.
    public mutating func addLine(to point: PixelPoint) {
        precondition(point.horizontal.isFinite && point.vertical.isFinite)
        elements.append(.line(point))
    }

    /// Connects the current contour to its starting point.
    public mutating func closeSubpath() {
        elements.append(.close)
    }

    /// Appends a clockwise rectangular contour in the top-left-origin coordinate system.
    public mutating func addRect(_ rectangle: PixelRect) {
        guard rectangle.width > 0 && rectangle.height > 0 else { return }
        let origin = rectangle.origin
        move(to: origin)
        addLine(to: PixelPoint(x: origin.horizontal + rectangle.width, y: origin.vertical))
        addLine(to: PixelPoint(x: origin.horizontal + rectangle.width, y: origin.vertical + rectangle.height))
        addLine(to: PixelPoint(x: origin.horizontal, y: origin.vertical + rectangle.height))
        closeSubpath()
    }

    /// Appends a clockwise ellipse starting at the midpoint of its right edge.
    /// This starting point remains current for subsequent segments.
    /// Empty rectangles add no contour.
    public mutating func addEllipse(in rectangle: PixelRect) {
        guard rectangle.width > 0 && rectangle.height > 0 else { return }
        elements.append(.ellipse(rectangle))
    }
}
