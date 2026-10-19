@MainActor
package final class HarfBuzzTextRenderer {
    package static let shared = HarfBuzzTextRenderer(font: SystemFontLocator.locate())
    private static let maximumCachedLayouts = 128

    private struct Key: Hashable {
        let text: String
        let style: TextStyle
    }

    private let font: HarfBuzzFont?
    private var cache: [Key: TextLayout] = [:]
    private var cacheOrder: [Key] = []
    private let fallback = BitmapTextRenderer()

    package init(font location: FontLocation?) {
        font = location.flatMap(HarfBuzzFont.init)
    }

    package func layout(_ text: String, style: TextStyle) -> TextLayout {
        guard !text.isEmpty else { return .empty }
        let singleLine = String(
            text.map { character in
                let control = character.unicodeScalars.contains { scalar in
                    switch scalar.properties.generalCategory {
                    case .control, .lineSeparator, .paragraphSeparator: true
                    default: false
                    }
                }
                return control ? " " : character
            })
        let key = Key(text: singleLine, style: style)
        if let cached = cache[key] { return cached }
        let layout = font?.layout(singleLine, style: style) ?? fallback.layout(singleLine, style: style)
        if cacheOrder.count == Self.maximumCachedLayouts {
            cache.removeValue(forKey: cacheOrder.removeFirst())
        }
        cache[key] = layout
        cacheOrder.append(key)
        return layout
    }
}
