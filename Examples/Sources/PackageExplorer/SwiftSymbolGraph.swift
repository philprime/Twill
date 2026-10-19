import Foundation

/// The subset of compiler symbol-graph JSON needed by the explorer.
struct SwiftSymbolGraph: Decodable {
    struct Module: Decodable {
        let name: String
    }

    struct Symbol: Decodable {
        struct Identifier: Decodable { let precise: String }
        struct Kind: Decodable { let identifier: String }
        struct Names: Decodable { let title: String }
        struct Fragment: Decodable { let spelling: String }
        struct Location: Decodable {
            struct Position: Decodable { let line: Int }
            let uri: String
            let position: Position
        }

        let identifier: Identifier
        let kind: Kind
        let names: Names
        let pathComponents: [String]
        let declarationFragments: [Fragment]?
        let location: Location?
    }

    struct Relationship: Decodable {
        let source: String
        let target: String
        let kind: String
    }

    let module: Module
    let symbols: [Symbol]
    let relationships: [Relationship]
}
