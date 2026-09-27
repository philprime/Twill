/// A completed cell frame. Mounted identity, focus, and scheduling stay with the host.
struct FrameSnapshot {
    let grid: CellGrid?
    let caret: CellPosition?
}
