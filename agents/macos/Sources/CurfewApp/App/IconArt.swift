#if DEBUG
import SwiftUI

struct IconArt: View {
    var body: some View {
        Canvas { context, size in
            let unit = size.width / 1024
            let tile = CGRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
            let shape = RoundedRectangle(cornerRadius: 185 * unit, style: .continuous).path(in: tile)
            context.fill(shape, with: .color(.black))
            context.stroke(shape, with: .color(Color(white: 0.18)), lineWidth: 2 * unit)
            let scale = 824 * unit / 80
            func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
                CGRect(x: tile.midX + (x - 54) * scale, y: tile.midY + (y - 54) * scale, width: width * scale, height: height * scale)
            }
            let inner = Path(ellipseIn: box(35, 31, 38, 38))
            let ring = Path(ellipseIn: box(29, 33, 50, 50)).subtracting(inner)
            let hand = Path(roundedRect: box(50, 25, 8, 33), cornerRadius: 4 * scale)
            context.fill(ring.union(hand), with: .color(.white))
        }
        .frame(width: 1024, height: 1024)
    }
}
#endif
