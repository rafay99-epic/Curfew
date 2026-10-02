import CoreImage
import Foundation

public enum QRMatrix {
    public static func modules(_ text: String) -> [[Bool]]? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let image = filter.outputImage else { return nil }
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt8](repeating: 255, count: width * height)
        CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
            .render(image, toBitmap: &pixels, rowBytes: width, bounds: image.extent, format: .L8, colorSpace: nil)
        let grid = (0..<height).map { row in (0..<width).map { column in pixels[row * width + column] < 128 } }
        return trimmed(grid)
    }

    private static func trimmed(_ grid: [[Bool]]) -> [[Bool]]? {
        let rows = grid.indices.filter { grid[$0].contains(true) }
        let columns = (grid.first?.indices ?? 0..<0).filter { column in grid.contains { $0[column] } }
        guard let top = rows.first, let bottom = rows.last, let left = columns.first, let right = columns.last else { return nil }
        return grid[top...bottom].map { Array($0[left...right]) }
    }
}
