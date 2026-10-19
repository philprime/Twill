import Foundation

/// Affine state is independent of the shared bitmap. Concatenation applies
/// new operations in local coordinates, so translating then scaling preserves the origin.
struct PixelTransform {
    var horizontalScale = 1.0
    var verticalShear = 0.0
    var horizontalShear = 0.0
    var verticalScale = 1.0
    var horizontalOffset = 0.0
    var verticalOffset = 0.0

    var maximumScale: Double {
        hypot(horizontalScale, verticalShear) + hypot(horizontalShear, verticalScale)
    }

    func apply(_ point: PixelPoint) -> PixelPoint {
        PixelPoint(
            x: horizontalScale * point.horizontal + horizontalShear * point.vertical + horizontalOffset,
            y: verticalShear * point.horizontal + verticalScale * point.vertical + verticalOffset)
    }

    var inverse: Self? {
        let determinant = horizontalScale * verticalScale - verticalShear * horizontalShear
        guard determinant.isFinite && determinant != 0 else { return nil }
        var result = Self()
        result.horizontalScale = verticalScale / determinant
        result.verticalShear = -verticalShear / determinant
        result.horizontalShear = -horizontalShear / determinant
        result.verticalScale = horizontalScale / determinant
        result.horizontalOffset = -(result.horizontalScale * horizontalOffset + result.horizontalShear * verticalOffset)
        result.verticalOffset = -(result.verticalShear * horizontalOffset + result.verticalScale * verticalOffset)
        return result
    }

    mutating func translate(horizontal: Double, vertical: Double) {
        let origin = apply(PixelPoint(x: horizontal, y: vertical))
        horizontalOffset = origin.horizontal
        verticalOffset = origin.vertical
    }

    mutating func scale(horizontal: Double, vertical: Double) {
        horizontalScale *= horizontal
        verticalShear *= horizontal
        horizontalShear *= vertical
        verticalScale *= vertical
    }

    mutating func rotate(_ angle: Double) {
        let cosine = cos(angle)
        let sine = sin(angle)
        let previous = self
        horizontalScale = previous.horizontalScale * cosine + previous.horizontalShear * sine
        verticalShear = previous.verticalShear * cosine + previous.verticalScale * sine
        horizontalShear = previous.horizontalShear * cosine - previous.horizontalScale * sine
        verticalScale = previous.verticalScale * cosine - previous.verticalShear * sine
    }
}
