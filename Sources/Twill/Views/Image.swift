import Foundation

/// Immutable PNG data. File loading belongs to the caller, not view evaluation.
public struct Image: Sendable, Equatable {
    public enum InvalidImage: Error { case invalidPNG }

    let data: Data
    public let pixelWidth: Int
    public let pixelHeight: Int

    /// Checks the PNG signature and dimensions. Pixel decoding is delegated to the terminal.
    public init(pngData: Data) throws {
        let bytes = Array(pngData.prefix(24))
        let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
        guard bytes.count == 24, Array(bytes.prefix(8)) == signature,
            Array(bytes[8..<16]) == [0, 0, 0, 13, 73, 72, 68, 82]
        else { throw InvalidImage.invalidPNG }
        func dimension(at offset: Int) -> Int {
            bytes[offset..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
        }
        let width = dimension(at: 16)
        let height = dimension(at: 20)
        guard width > 0, height > 0, width <= Int(Int32.max), height <= Int(Int32.max) else {
            throw InvalidImage.invalidPNG
        }
        data = pngData
        pixelWidth = width
        pixelHeight = height
    }
}
