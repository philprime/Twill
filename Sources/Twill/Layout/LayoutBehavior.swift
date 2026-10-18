/// Scalar sizing intent used by ancestors before measuring flexible children.
///
/// Inherited intent passes through composition, filling accepts available space, and
/// intrinsic intent prevents a fixed or capped wrapper from advertising a child's fill.
/// Keeping this metadata on layouts avoids concrete-type checks in tree traversal.
struct LayoutBehavior {
    enum Fill {
        case inherited
        case filling
        case intrinsic
    }

    var width: Fill = .inherited
    var height: Fill = .inherited
}
