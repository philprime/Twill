extension PixelCanvas {
    /// Presentation-scoped drawing state referencing a fixed RGBA destination.
    /// Copies share pixels but have independent transforms, clipping, and opacity.
    /// Draw only during the canvas callback; do not retain a context for later use.
    @MainActor
    public struct Context {
        let surface: PixelSurface
        private var transform = PixelTransform()
        private var clips: [PixelRasterPath] = []

        /// The opacity applied to subsequent operations, from zero through one.
        public var opacity: Double = 1 {
            didSet { precondition(opacity.isFinite && (0...1).contains(opacity)) }
        }

        init(surface: PixelSurface) {
            self.surface = surface
        }

        /// Fills a path using nonzero winding and source-over compositing.
        /// Open contours are implicitly closed. Colors belong to the operation,
        /// not to mutable context state.
        public func fill(_ path: Path, with color: PixelColor) {
            let raster = PixelRasterPath(path, transform: transform, resolutionScale: transform.maximumScale)
            guard let bounds = raster.bounds else { return }
            paint(bounds: bounds, color: color) { raster.contains($0) }
        }

        /// Strokes a path with round caps and joins, compositing the entire stroke once.
        /// Width is measured in local coordinates and follows the current transform.
        /// Zero width draws nothing. Open contours are not implicitly closed.
        public func stroke(_ path: Path, with color: PixelColor, lineWidth: Double = 1) {
            precondition(lineWidth.isFinite && lineWidth >= 0)
            guard lineWidth > 0, let inverse = transform.inverse else { return }
            let raster = PixelRasterPath(path, resolutionScale: transform.maximumScale)
            guard let bounds = raster.applying(transform).bounds else { return }
            let expanded = bounds.expanded(by: lineWidth / 2 * transform.maximumScale)
            paint(bounds: expanded, color: color) {
                raster.containsStroke(inverse.apply($0), radius: lineWidth / 2)
            }
        }

        /// Intersects the current clip with this path, capturing its current transform.
        /// Subsequent transforms do not move an established clip.
        public mutating func clip(to path: Path) {
            clips.append(PixelRasterPath(path, transform: transform, resolutionScale: transform.maximumScale))
        }

        /// Translates subsequent drawing in the current local coordinate system.
        public mutating func translateBy(x horizontal: Double, y vertical: Double) {
            precondition(horizontal.isFinite && vertical.isFinite)
            transform.translate(horizontal: horizontal, vertical: vertical)
        }

        /// Scales subsequent drawing, including stroke widths. Zero scales draw no area.
        public mutating func scaleBy(x horizontal: Double, y vertical: Double) {
            precondition(horizontal.isFinite && vertical.isFinite)
            transform.scale(horizontal: horizontal, vertical: vertical)
        }

        /// Rotates subsequent drawing clockwise in top-left-origin coordinates, in radians.
        public mutating func rotate(by angle: Double) {
            precondition(angle.isFinite)
            transform.rotate(angle)
        }

        private func paint(
            bounds: PixelPathBounds, color: PixelColor, contains: (PixelPoint) -> Bool
        ) {
            var clippedBounds = bounds
            for clip in clips {
                guard let clipBounds = clip.bounds else { return }
                clippedBounds = clippedBounds.intersection(clipBounds)
            }
            surface.paint(bounds: clippedBounds, color: color, opacity: opacity) { point in
                contains(point) && clips.allSatisfy { $0.contains(point) }
            }
        }
    }
}
