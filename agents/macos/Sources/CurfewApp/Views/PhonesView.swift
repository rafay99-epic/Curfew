import CurfewControl
import SwiftUI

struct PhonesView: View {
    let phones: [ControlPhone]
    let remove: (ControlPhone) -> Void
    @State private var confirming: ControlPhone?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(phones) { phone in
                HairlineRow {
                    Text(phone.name)
                        .font(Theme.serif(24))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                } trailing: {
                    TextAction("Remove") { confirming = phone }
                }
            }
        }
        .alert(
            confirming.map { "Remove \($0.name)?" } ?? "",
            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
            presenting: confirming
        ) { phone in
            Button("Remove", role: .destructive) { remove(phone) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It can no longer control this Mac.")
        }
    }
}
