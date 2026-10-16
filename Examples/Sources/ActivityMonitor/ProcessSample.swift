import Foundation

struct ProcessSample: Identifiable, Sendable {
    let id: Int
    let parentID: Int
    let userID: Int
    let cpuPercent: Double
    let residentBytes: UInt64
    let status: String
    let command: String

    var name: String { (command as NSString).lastPathComponent }

    static func parse(_ output: String) -> [Self] {
        output.split(separator: "\n").compactMap { line in
            let fields = line.split(maxSplits: 6, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
            guard fields.count == 7,
                let id = Int(fields[0]), id > 0,
                let parentID = Int(fields[1]), let userID = Int(fields[2]),
                let cpu = Double(fields[3]), cpu.isFinite, cpu >= 0,
                let residentKiB = UInt64(fields[4]), residentKiB <= UInt64.max / 1024
            else { return nil }
            // Command names are external data. Keep terminal control characters out of the UI.
            let command = String(fields[6].unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
            return Self(
                id: id, parentID: parentID, userID: userID, cpuPercent: cpu,
                residentBytes: residentKiB * 1024, status: String(fields[5]), command: command)
        }
    }
}
