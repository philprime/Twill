extension Text {
    /// How a logical text line uses a finite proposed terminal-cell width.
    public enum LineBreakMode: Hashable, Sendable {
        /// Prefer breaks at spaces, splitting oversized words only at grapheme boundaries.
        case wordWrapping
        /// Break at complete grapheme boundaries, preserving spaces between rows.
        case characterWrapping
        /// Preserve logical lines and clip horizontal overflow without wrapping.
        case clipping
    }

    /// The part of omitted text replaced by a cell-safe ellipsis.
    public enum TruncationMode: Hashable, Sendable {
        /// Preserve the end of the text.
        case head
        /// Preserve both ends of the text.
        case middle
        /// Preserve the beginning of the text.
        case tail
    }
}
