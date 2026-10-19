/// Grapheme offsets are shared by all editors. Whitespace separates runs, while
/// punctuation is distinct from Unicode letters, numbers and underscores.
struct TextWordNavigation {
    private enum Kind { case whitespace, word, punctuation }
    private let characters: [Character]

    init(_ text: String) { characters = Array(text) }

    func destination(from offset: Int, backwards: Bool) -> Int {
        backwards ? previous(from: offset) : next(from: offset)
    }

    private func previous(from offset: Int) -> Int {
        var result = offset
        while result > 0, kind(characters[result - 1]) == .whitespace { result -= 1 }
        guard result > 0 else { return result }
        let run = kind(characters[result - 1])
        while result > 0, kind(characters[result - 1]) == run { result -= 1 }
        return result
    }

    private func next(from offset: Int) -> Int {
        var result = offset
        while result < characters.count, kind(characters[result]) == .whitespace { result += 1 }
        guard result < characters.count else { return result }
        let run = kind(characters[result])
        while result < characters.count, kind(characters[result]) == run { result += 1 }
        return result
    }

    private func kind(_ character: Character) -> Kind {
        if character.isWhitespace { return .whitespace }
        if character.isLetter || character.isNumber || character == "_" { return .word }
        return .punctuation
    }
}
