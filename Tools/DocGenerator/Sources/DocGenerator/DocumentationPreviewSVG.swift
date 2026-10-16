import Foundation

@testable import Twill

/// A terminal theme for documentation. ANSI colors are theme-dependent in live terminals.
enum DocumentationPreviewSVG {
    private static let cellWidth = 10
    private static let cellHeight = 20
    private static let inset = 16
    private static let foreground = "#e6edf3"
    private static let background = "#161b22"
    private static let palette = [
        "#161b22", "#e06c75", "#98c379", "#e5c07b", "#61afef", "#c678dd", "#56b6c2", "#abb2bf",
        "#5c6370", "#ff7a85", "#b3e695", "#ffe09e", "#82cfff", "#e7a1ff", "#7edee8", "#ffffff",
    ]

    static func color(_ color: Color?, fallback: String) -> String {
        switch color {
        case .rgb(let red, let green, let blue): String(format: "#%02x%02x%02x", red, green, blue)
        case .ansi(let entry): palette[entry.rawValue]
        case nil: fallback
        }
    }

    static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func render(_ grid: CellGrid?, caret: CellPosition?, title: String) -> String {
        let width = max(1, grid?.size.width ?? 0) * cellWidth + inset * 2
        let height = max(1, grid?.size.height ?? 0) * cellHeight + inset * 2
        var elements = [
            "<!-- dprint-ignore-file -->",
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(width)\" height=\"\(height)\" "
                + "viewBox=\"0 0 \(width) \(height)\" role=\"img\" aria-labelledby=\"title\">",
            "<title id=\"title\">\(escaped(title))</title>",
            "<rect width=\"100%\" height=\"100%\" rx=\"8\" fill=\"\(background)\"/>",
        ]
        if let grid {
            appendCells(grid, to: &elements)
            for image in grid.images {
                let rect = image.bounds
                elements.append(
                    "<image x=\"\(inset + rect.column * cellWidth)\" y=\"\(inset + rect.row * cellHeight)\" "
                        + "width=\"\(rect.width * cellWidth)\" height=\"\(rect.height * cellHeight)\" "
                        + "preserveAspectRatio=\"none\" "
                        + "href=\"data:image/png;base64,\(image.data.base64EncodedString())\"/>")
            }
        }
        if let caret {
            elements.append(
                "<path d=\"M\(inset + caret.column * cellWidth) \(inset + (caret.row + 1) * cellHeight - 1)"
                    + "h\(cellWidth)\" stroke=\"\(foreground)\" stroke-width=\"2\"/>")
        }
        elements.append("</svg>")
        return elements.joined(separator: "\n") + "\n"
    }

    private static func appendCells(_ grid: CellGrid, to elements: inout [String]) {
        for row in 0..<grid.size.height {
            for column in 0..<grid.size.width {
                let focused = grid.isFocused(column: column, row: row)
                let cellForeground = color(grid.foreground(column: column, row: row), fallback: foreground)
                let cellBackground = color(grid.background(column: column, row: row), fallback: background)
                let paper = focused ? cellForeground : cellBackground
                let originX = inset + column * cellWidth
                let originY = inset + row * cellHeight
                elements.append(
                    "<rect x=\"\(originX)\" y=\"\(originY)\" width=\"\(cellWidth)\" "
                        + "height=\"\(cellHeight)\" fill=\"\(paper)\"/>")

            }
        }
        for row in 0..<grid.size.height {
            for column in 0..<grid.size.width {
                guard case .glyph(let character, let span) = grid[column, row] else { continue }
                let ink =
                    grid.isFocused(column: column, row: row)
                    ? color(grid.background(column: column, row: row), fallback: background)
                    : color(grid.foreground(column: column, row: row), fallback: foreground)
                elements.append(
                    "<text x=\"\(inset + column * cellWidth)\" y=\"\(inset + row * cellHeight + 15)\" "
                        + "fill=\"\(ink)\" font-family=\"'SFMono-Regular',Consolas,'Liberation Mono',monospace\" "
                        + "font-size=\"16\" textLength=\"\(span * cellWidth)\" lengthAdjust=\"spacingAndGlyphs\">"
                        + "\(escaped(String(character)))</text>")
            }
        }
    }
}
