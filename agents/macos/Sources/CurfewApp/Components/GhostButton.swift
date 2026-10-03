import SwiftUI

struct GhostButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ButtonLabel(title: title, systemImage: systemImage, weight: .medium)
        }
        .buttonStyle(GhostStyle())
    }
}

private struct GhostStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(enabled ? Theme.text : Theme.faint)
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(enabled ? Theme.text : Theme.line2, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
