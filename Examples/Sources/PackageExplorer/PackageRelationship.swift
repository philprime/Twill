import Twill

struct PackageRelationship: Sendable {
    enum Kind: String, Sendable {
        case inheritance = "inheritsFrom"
        case conformance = "conformsTo"
        case nesting = "memberOf"

        var color: PixelColor {
            switch self {
            case .inheritance: PixelColor(red: 229, green: 192, blue: 123)
            case .conformance: PixelColor(red: 152, green: 195, blue: 121)
            case .nesting: PixelColor(red: 97, green: 175, blue: 239)
            }
        }

        var label: String {
            switch self {
            case .inheritance: "inherits"
            case .conformance: "conforms"
            case .nesting: "nested in"
            }
        }
    }

    let source: String
    let target: String
    let kind: Kind
}
