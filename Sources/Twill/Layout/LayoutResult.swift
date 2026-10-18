/// Geometry returned to the mounted runtime after a layout measures its children.
///
/// Placements correspond to the supplied subviews in order, including empty table slots.
/// No measurement handles or view descriptions escape the pass. The runtime associates
/// these rectangles with retained child identities for later drawing and focus reveal.
struct LayoutResult {
    let size: CellSize
    let placements: [CellRect]
}
