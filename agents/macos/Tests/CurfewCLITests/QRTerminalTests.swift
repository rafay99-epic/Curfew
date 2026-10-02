@testable import curfew
import CoreImage
import CurfewControl
import Testing

@Suite struct QRTerminalTests {
    let link = "curfew://pair?a=192.168.1.20:8787&i=0b825f00961665a4&c=ABCD2345EFGH6789"

    @Test func matrixDecodesBackToTheLink() throws {
        let matrix = try #require(QRMatrix.modules(link))
        let scale = 8
        let quiet = 4
        let size = (matrix.count + 2 * quiet) * scale
        var pixels = [UInt8](repeating: 255, count: size * size)
        for (row, line) in matrix.enumerated() {
            for (column, dark) in line.enumerated() where dark {
                for dy in 0..<scale {
                    for dx in 0..<scale {
                        pixels[((row + quiet) * scale + dy) * size + (column + quiet) * scale + dx] = 0
                    }
                }
            }
        }
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(
            width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
        let detector = try #require(CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil))
        let found = detector.features(in: CIImage(cgImage: image)).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
        #expect(found == [link])
    }

    @Test func findersAreTopLeftTopRightBottomLeft() throws {
        let matrix = try #require(QRMatrix.modules(link))
        let far = matrix.count - 7
        func finder(_ top: Int, _ left: Int) -> Bool {
            (0..<7).allSatisfy { y in
                (0..<7).allSatisfy { x in
                    let ring = max(abs(y - 3), abs(x - 3))
                    return matrix[top + y][left + x] == (ring != 2)
                }
            }
        }
        #expect(finder(0, 0) && finder(0, far) && finder(far, 0))
        #expect(!finder(far, far))
    }

    @Test func rendersHalfBlocksWithQuietZone() throws {
        let text = try #require(QRTerminal.render(link))
        let lines = text.split(separator: "\n")
        let matrix = try #require(QRMatrix.modules(link))
        #expect(lines.count == (matrix.count + 2 * QRTerminal.quietZone + 1) / 2)
        #expect(lines.allSatisfy { $0.hasPrefix("\u{1b}[38;5;16;48;5;231m    ") && $0.hasSuffix("\u{1b}[0m") })
    }
}
