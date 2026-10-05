import Foundation

/// Image placements travel with the cell snapshot so output remains host-owned.
struct ImagePlacement: Equatable {
    let data: Data
    let bounds: CellRect
}
