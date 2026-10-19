/// SGR intensity reset clears both bold and dim. Re-enable the surviving flag
/// rather than using a global reset that would also discard colors or focus.
enum TextAttributeEncoder {
    private enum SGR {
        static let bold = 1
        static let dim = 2
        static let italic = 3
        static let underline = 4
        static let normalIntensity = 22
        static let noItalic = 23
        static let noUnderline = 24
    }

    static func transition(to next: TextAttributes, from previous: TextAttributes) -> String {
        guard next != previous else { return "" }
        var codes: [Int] = []
        let removedIntensity = previous.subtracting(next).intersection(.intensity)
        if !removedIntensity.isEmpty {
            codes.append(SGR.normalIntensity)
            if next.contains(.bold) { codes.append(SGR.bold) }
            if next.contains(.dim) { codes.append(SGR.dim) }
        } else {
            let added = next.subtracting(previous)
            if added.contains(.bold) { codes.append(SGR.bold) }
            if added.contains(.dim) { codes.append(SGR.dim) }
        }
        if next.contains(.italic) != previous.contains(.italic) {
            codes.append(next.contains(.italic) ? SGR.italic : SGR.noItalic)
        }
        if next.contains(.underline) != previous.contains(.underline) {
            codes.append(next.contains(.underline) ? SGR.underline : SGR.noUnderline)
        }
        guard !codes.isEmpty else { return "" }
        return "\u{1B}[" + codes.map(String.init).joined(separator: ";") + "m"
    }
}
