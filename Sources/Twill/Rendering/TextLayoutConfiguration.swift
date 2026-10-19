struct TextLayoutConfiguration {
    var lineBreakMode: Text.LineBreakMode = .wordWrapping
    var lineLimit: Int?
    var truncationMode: Text.TruncationMode?

    var effectiveTruncationMode: Text.TruncationMode? {
        truncationMode ?? lineLimit.map { _ in .tail }
    }
}
