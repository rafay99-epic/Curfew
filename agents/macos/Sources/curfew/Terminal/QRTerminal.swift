import CurfewControl

enum QRTerminal {
    static let quietZone = 4

    static func render(_ text: String) -> String? {
        guard let matrix = QRMatrix.modules(text) else { return nil }
        let size = matrix.count + 2 * quietZone
        let dark: (Int, Int) -> Bool = { row, column in
            let y = row - quietZone
            let x = column - quietZone
            return matrix.indices.contains(y) && matrix[y].indices.contains(x) && matrix[y][x]
        }
        return stride(from: 0, to: size, by: 2).map { row in
            let line = (0..<size).map { column -> Character in
                switch (dark(row, column), dark(row + 1, column)) {
                case (false, false): " "
                case (false, true): "▄"
                case (true, false): "▀"
                case (true, true): "█"
                }
            }
            return "\u{1b}[38;5;16;48;5;231m" + String(line) + "\u{1b}[0m"
        }.joined(separator: "\n")
    }
}
