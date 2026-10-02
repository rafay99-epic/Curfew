import CurfewControl
import SwiftUI

struct QRCodeView: View {
    private let modules: [[Bool]]

    init(_ text: String) {
        modules = QRMatrix.modules(text) ?? []
    }

    var body: some View {
        Canvas { context, size in
            let count = CGFloat(modules.count)
            guard count > 0 else { return }
            let cell = min(size.width, size.height) / count
            var path = Path()
            for (row, line) in modules.enumerated() {
                for (column, dark) in line.enumerated() where dark {
                    path.addRect(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell))
                }
            }
            context.fill(path, with: .color(.black))
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.radius))
        .accessibilityLabel("Pairing code")
    }
}
