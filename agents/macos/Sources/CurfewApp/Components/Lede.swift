import SwiftUI

enum LedePart: Equatable {
    case plain(String)
    case strong(String)
}

struct Lede: View {
    let parts: [LedePart]

    init(_ parts: LedePart...) {
        self.parts = parts
    }

    init(parts: [LedePart]) {
        self.parts = parts
    }

    var body: some View {
        Text(attributed)
            .font(Theme.sans(15))
            .foregroundStyle(Theme.lede)
            .lineSpacing(4)
            .frame(maxWidth: 440, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributed: AttributedString {
        parts.reduce(into: AttributedString()) { text, part in
            switch part {
            case .plain(let words):
                text += AttributedString(words)
            case .strong(let words):
                var run = AttributedString(words)
                run.font = Theme.sans(15, .semibold)
                run.foregroundColor = Theme.text
                text += run
            }
        }
    }
}
