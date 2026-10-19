import Foundation

#if canImport(CoreText)
    import CoreText
#endif

/// Font discovery runs once at composition, never as a presentation poll.
/// Linux uses standard font directories rather than requiring Fontconfig packages.
enum SystemFontLocator {
    static func locate() -> FontLocation? {
        #if canImport(CoreText)
            guard let font = CTFontCreateUIFontForLanguage(.userFixedPitch, 12, nil),
                let url = CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL
            else { return nil }
            return FontLocation(path: url.path, postScriptName: CTFontCopyPostScriptName(font) as String)
        #else
            let home = FileManager.default.homeDirectoryForCurrentUser
            return locate(in: [
                home.appendingPathComponent(".local/share/fonts"),
                home.appendingPathComponent(".fonts"),
                URL(fileURLWithPath: "/usr/local/share/fonts"),
                URL(fileURLWithPath: "/usr/share/fonts"),
            ])
        #endif
    }

    static func locate(in directories: [URL]) -> FontLocation? {
        let preferredNames = [
            "dejavusansmono.ttf", "liberationmono-regular.ttf", "ubuntumono-r.ttf",
            "notosansmono-regular.ttf", "freemono.ttf",
        ]
        for directory in directories {
            guard
                let files = FileManager.default.enumerator(
                    at: directory, includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants])
            else { continue }
            let candidates = files.compactMap { $0 as? URL }.filter { url in
                let name = url.lastPathComponent.lowercased()
                return ["ttf", "otf", "ttc"].contains(url.pathExtension.lowercased())
                    && (name.contains("mono") || name.contains("code") || name.contains("iosevka"))
                    && !name.contains("bold") && !name.contains("italic") && !name.contains("oblique")
            }.sorted { left, right in
                let leftRank =
                    preferredNames.firstIndex(of: left.lastPathComponent.lowercased()) ?? preferredNames.count
                let rightRank =
                    preferredNames.firstIndex(of: right.lastPathComponent.lowercased()) ?? preferredNames.count
                return leftRank == rightRank ? left.path < right.path : leftRank < rightRank
            }
            if let file = candidates.first { return FontLocation(path: file.path) }
        }
        return nil
    }
}
