internal import TwillTextRendering

extension PixelCanvas {
    /// Presentation-scoped drawing state referencing a fixed RGBA destination.
    /// Copies share pixels but have independent transforms, clipping, and opacity.
    /// Draw only during the canvas callback; do not retain a context for later use.
    @MainActor
    public struct Context {
        let surface: PixelSurface
        private let textRenderer: TextRenderer
        private var transform = PixelTransform()
        private var clips: [PixelRasterPath] = []

        /// The opacity applied to subsequent operations, from zero through one.
        public var opacity: Double = 1 {
            didSet { precondition(opacity.isFinite && (0...1).contains(opacity)) }
        }

        init(surface: PixelSurface, textRenderer: TextRenderer = HarfBuzzTextRenderer.shared) {
            self.surface = surface
            self.textRenderer = textRenderer
        }

        /// Measures a label's layout box before context transforms or clipping.
        public func measure(_ text: PixelText) -> PixelTextMetrics {
            let layout = layout(text)
            return PixelTextMetrics(width: layout.width, height: layout.height, firstBaseline: layout.firstBaseline)
        }

        /// Draws a label with its normalized layout anchor at a local pixel position.
        /// Transforms, clipping, and opacity apply as they do to paths.
        public func draw(_ text: PixelText, at point: PixelPoint, anchor: UnitPoint = .center) {
            precondition(point.horizontal.isFinite && point.vertical.isFinite)
            guard let inverse = transform.inverse else { return }
            let layout = layout(text)
            let bitmap = layout.bitmap
            guard bitmap.width > 0 && bitmap.height > 0 else { return }
            let left = point.horizontal - anchor.horizontal * layout.width + bitmap.originX
            let top = point.vertical - anchor.vertical * layout.height + bitmap.originY
            let rectangle = PixelRect(x: left, y: top, width: Double(bitmap.width), height: Double(bitmap.height))
            let raster = PixelRasterPath(Path(rectangle), transform: transform)
            guard let bounds = raster.bounds else { return }
            paint(
                bounds: bounds, color: text.color,
                coverage: { point in
                    let local = inverse.apply(point)
                    let column = local.horizontal - left
                    let row = local.vertical - top
                    guard column >= 0, row >= 0, column < Double(bitmap.width), row < Double(bitmap.height) else {
                        return 0
                    }
                    return Double(bitmap.coverage[Int(row) * bitmap.width + Int(column)]) / 255
                })
        }

        private func layout(_ text: PixelText) -> TextLayout {
            textRenderer.layout(
                text.content,
                style: TextStyle(size: text.font.size, weight: text.font.weight == .bold ? .bold : .regular))
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
            paint(bounds: bounds, color: color, coverage: { contains($0) ? 1 : 0 })
        }

        private func paint(
            bounds: PixelPathBounds, color: PixelColor, coverage: (PixelPoint) -> Double
        ) {
            var clippedBounds = bounds
            for clip in clips {
                guard let clipBounds = clip.bounds else { return }
                clippedBounds = clippedBounds.intersection(clipBounds)
            }
            surface.paint(
                bounds: clippedBounds, color: color, opacity: opacity,
                coverage: { point in
                    clips.allSatisfy { $0.contains(point) } ? coverage(point) : 0
                })
        }
    }
}
