/// Node-local presentation data, detached from mounted identity and mutable state.
///
/// The mounted adapter snapshots the current drawing content, decoration, and viewport
/// offsets. This value can measure and draw with child callbacks, but has no nodes to
/// reconcile, focus to choose, timers to register, or terminal output to write. Leaves
/// continue using PrimitiveDrawing rather than introducing another drawing protocol.
@MainActor
enum NodePresentation {
    case content
    case drawing(any PrimitiveDrawing, caretColumn: Int?)
    case background(Color?)
    case border(glyphs: Border.Glyphs, style: ResolvedStyle, title: TextDrawing?)
    case scroll(offset: Int, contentHeight: Int, indicators: ScrollIndicatorVisibility)
    case editor(snapshot: TextEditorSnapshot, offset: CellPosition)
    case tabs(bar: TextDrawing)

    // Containers delegate child appearance. Only leaves and editors need the mounted
    // focus-path walk, which would otherwise repeat for every transparent wrapper.
    var usesFocusAppearance: Bool {
        switch self {
        case .drawing, .editor: return true
        default: return false
        }
    }

    /// Child measurement remains a runtime capability, not access to the tree. A
    /// decorator changes proposals and outer bounds without evaluating view bodies.
    /// Viewport memory is updated by the mounted owner after the size is known.
    func sizeThatFits(_ proposal: ProposedCellSize, content: (ProposedCellSize) -> CellSize) -> CellSize {
        switch self {
        case .drawing(let drawing, _):
            return drawing.sizeThatFits(proposal)
        case .editor(let snapshot, _):
            let layout = snapshot.layout(width: proposal.width)
            return CellSize(width: proposal.width ?? layout.width, height: proposal.height ?? layout.lines.count)
        case .border(_, _, let title):
            let inner = ProposedCellSize(
                width: proposal.width.map { max(0, $0 - 2) },
                height: proposal.height.map { max(0, $0 - 2) })
            let size = content(inner)
            let titleWidth = title.map { $0.sizeThatFits(.unspecified).width + 3 } ?? 0
            return proposal.constrain(CellSize(width: max(size.width + 2, titleWidth), height: size.height + 2))
        case .scroll(_, _, let indicators):
            let innerWidth = proposal.width.map { max(0, $0 - indicators.reservedColumns) }
            let measured = content(ProposedCellSize(width: innerWidth))
            if indicators == .visible {
                return CellSize(
                    width: proposal.width ?? measured.width + indicators.reservedColumns,
                    height: proposal.height ?? measured.height)
            }
            return proposal.constrain(measured)
        case .tabs(let bar):
            let barSize = bar.sizeThatFits(.unspecified)
            let size = content(
                ProposedCellSize(width: proposal.width, height: proposal.height.map { max(0, $0 - 1) }))
            return proposal.constrain(CellSize(width: max(barSize.width, size.width), height: 1 + size.height))
        case .content, .background:
            return content(proposal)
        }
    }
}
