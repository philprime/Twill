#if TESTING
    @MainActor
    package protocol TextRenderer: AnyObject {
        func layout(_ text: String, style: TextStyle) -> TextLayout
    }

    extension HarfBuzzTextRenderer: TextRenderer {}
#else
    package typealias TextRenderer = HarfBuzzTextRenderer
#endif
