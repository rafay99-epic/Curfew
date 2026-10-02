import SwiftUI

struct SerifTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(Theme.serif(44))
            .foregroundStyle(Theme.text)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
            .padding(.bottom, 10)
            .accessibilityAddTraits(.isHeader)
    }
}
