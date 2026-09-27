/// Terminal conventions, not font metrics. Ambiguous-width characters occupy one
/// column. Emoji presentation and East Asian wide/fullwidth characters occupy two.
/// A terminal configured for different ambiguous/emoji widths may render differently.
enum TerminalCharacterWidth {
    private enum Scalar {
        static let emojiSelector: UInt32 = 0xFE0F
        static let textSelector: UInt32 = 0xFE0E
        static let keycap: UInt32 = 0x20E3

        static let hangulJamo: ClosedRange<UInt32> = 0x1100...0x115F
        static let angleBrackets: ClosedRange<UInt32> = 0x2329...0x232A
        static let cjkRadicalsAndSymbols: ClosedRange<UInt32> = 0x2E80...0x303E
        static let cjkKanaAndYi: ClosedRange<UInt32> = 0x3040...0xA4CF
        static let hangulJamoExtended: ClosedRange<UInt32> = 0xA960...0xA97C
        static let hangulSyllables: ClosedRange<UInt32> = 0xAC00...0xD7A3
        static let cjkCompatibilityIdeographs: ClosedRange<UInt32> = 0xF900...0xFAFF
        static let verticalForms: ClosedRange<UInt32> = 0xFE10...0xFE19
        static let cjkCompatibilityForms: ClosedRange<UInt32> = 0xFE30...0xFE6F
        static let fullwidthForms: ClosedRange<UInt32> = 0xFF01...0xFF60
        static let fullwidthSymbols: ClosedRange<UInt32> = 0xFFE0...0xFFE6
        static let supplementaryEastAsianScripts: ClosedRange<UInt32> = 0x16FE0...0x18DFF
        static let supplementaryKana: ClosedRange<UInt32> = 0x1AFF0...0x1B2FF
        static let enclosedIdeographs: ClosedRange<UInt32> = 0x1F200...0x1F251
        static let supplementaryIdeographs: ClosedRange<UInt32> = 0x20000...0x3FFFD
    }

    private static let wideRanges = [
        Scalar.hangulJamo, Scalar.angleBrackets, Scalar.cjkRadicalsAndSymbols,
        Scalar.cjkKanaAndYi, Scalar.hangulJamoExtended, Scalar.hangulSyllables,
        Scalar.cjkCompatibilityIdeographs, Scalar.verticalForms, Scalar.cjkCompatibilityForms,
        Scalar.fullwidthForms, Scalar.fullwidthSymbols, Scalar.supplementaryEastAsianScripts,
        Scalar.supplementaryKana, Scalar.enclosedIdeographs, Scalar.supplementaryIdeographs,
    ]

    static func columns(for character: Character) -> Int {
        let scalars = character.unicodeScalars
        let hasTextSelector = scalars.contains { $0.value == Scalar.textSelector }
        let hasEmojiSelector = scalars.contains { $0.value == Scalar.emojiSelector || $0.value == Scalar.keycap }
        let hasEmojiPresentation =
            scalars.contains { $0.properties.isEmojiPresentation }
            || (hasEmojiSelector && scalars.contains { $0.properties.isEmoji })
        if !hasTextSelector && hasEmojiPresentation { return 2 }
        return scalars.contains { scalar in
            wideRanges.contains { $0.contains(scalar.value) }
        } ? 2 : 1
    }
}
