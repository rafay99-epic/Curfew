import CurfewControl
import SwiftUI

struct PairingView: View {
    let offer: PairingOffer
    let secondsLeft: Int

    var body: some View {
        HStack(alignment: .top, spacing: 26) {
            QRCodeView(offer.uri)
                .frame(width: 200, height: 200)
            VStack(alignment: .leading, spacing: 0) {
                Text("Scan with Curfew, or type")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.dim)
                Text(offer.address)
                    .font(Theme.mono(14))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(offer.codeLines, id: \.self) { line in
                        Text(line).font(Theme.mono(22, .medium)).tracking(1.3)
                    }
                }
                .foregroundStyle(Theme.text)
                .padding(.top, 8)
                .textSelection(.enabled)
                Text("expires in \(Self.clock(secondsLeft))")
                    .font(Theme.mono(12.5))
                    .foregroundStyle(Theme.dim)
                    .monospacedDigit()
                    .padding(.top, 10)
            }
            .padding(.top, 4)
        }
    }

    static func clock(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return "\(value / 60):" + String(format: "%02d", value % 60)
    }
}
