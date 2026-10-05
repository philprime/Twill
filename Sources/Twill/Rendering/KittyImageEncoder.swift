/// The static-image subset of the Kitty graphics protocol supported by Ghostty.
/// Direct transmission works over remote connections without exposing local paths.
enum KittyImageEncoder {
    private static let payloadLimit = 4096
    private static let start = "\u{1B}_G"
    private static let end = "\u{1B}\\"

    static func delete(id: UInt32) -> String {
        "\(start)a=d,d=I,i=\(id),q=2\(end)"
    }

    static func display(_ image: ImagePlacement, id: UInt32) -> String {
        let bounds = image.bounds
        var output = "\r"
        if bounds.row > 0 { output += "\u{1B}[\(bounds.row)B" }
        if bounds.column > 0 { output += "\u{1B}[\(bounds.column)C" }
        let payload = image.data.base64EncodedString()
        var index = payload.startIndex
        var first = true
        while index < payload.endIndex {
            let next = payload.index(index, offsetBy: payloadLimit, limitedBy: payload.endIndex) ?? payload.endIndex
            let more = next < payload.endIndex ? 1 : 0
            let control = first ? "a=T,t=d,f=100,q=2,C=1,i=\(id),c=\(bounds.width),r=\(bounds.height)," : ""
            output += "\(start)\(control)m=\(more);\(payload[index..<next])\(end)"
            first = false
            index = next
        }
        // C=1 prevents the terminal from advancing the cursor after display.
        output += "\r"
        if bounds.row > 0 { output += "\u{1B}[\(bounds.row)A" }
        return output
    }
}
