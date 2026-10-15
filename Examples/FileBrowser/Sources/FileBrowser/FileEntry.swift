import Foundation
import Twill

struct FileEntry: Identifiable {
    var id: String { url.path }
    let url: URL
    let isDirectory: Bool

    static func contents(of directory: URL, showHidden: Bool) throws -> [FileEntry] {
        try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey],
            options: showHidden ? [] : [.skipsHiddenFiles]
        ).map { url in
            FileEntry(url: url, isDirectory: (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true)
        }.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
        }
    }
}

enum FilePreview {
    case text([String])
    case image(Image)

    // Bound memory use and never open devices, sockets, or FIFOs for preview.
    private static let maximumBytes = 8 * 1024 * 1024

    static func load(_ url: URL) throws -> FilePreview {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw PreviewError.notRegular }
        guard (values.fileSize ?? 0) <= maximumBytes else { throw PreviewError.tooLarge }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else { throw PreviewError.tooLarge }
        if let image = try? Image(pngData: data) { return .image(image) }
        guard let text = String(data: data, encoding: .utf8), !data.contains(0) else {
            throw PreviewError.unsupported
        }
        return .text(text.components(separatedBy: .newlines))
    }

    enum PreviewError: LocalizedError {
        case notRegular, tooLarge, unsupported

        var errorDescription: String? {
            switch self {
            case .notRegular: "Only regular files can be viewed."
            case .tooLarge: "Preview is limited to files up to 8 MiB."
            case .unsupported: "Unsupported file format. This browser displays UTF-8 text and PNG images."
            }
        }
    }
}
