enum TextLayoutChange {
    case alignment(HorizontalAlignment)
    case lineBreakMode(Text.LineBreakMode)
    case lineLimit(Int?)
    case truncationMode(Text.TruncationMode)
}
