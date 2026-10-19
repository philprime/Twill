import Foundation

enum PackageTypeKind: String, CaseIterable, Sendable {
    case structure = "struct"
    case enumeration = "enum"
    case classType = "class"
    case protocolType = "protocol"
    case actor

    static func resolve(_ identifier: String, declaration: [String]) -> Self? {
        switch identifier {
        case "swift.struct": .structure
        case "swift.enum": .enumeration
        case "swift.class": declaration.contains("actor") ? .actor : .classType
        case "swift.actor": .actor
        case "swift.protocol": .protocolType
        default: nil
        }
    }
}

struct PackageType: Sendable {
    let id: String
    let name: String
    let module: String
    let kind: PackageTypeKind
    let declaration: String
    let source: URL?
    let line: Int?
}
