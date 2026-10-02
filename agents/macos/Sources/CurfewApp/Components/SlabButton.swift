import SwiftUI

struct SlabButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ButtonLabel(title: title, systemImage: systemImage, weight: .semibold)
        }
        .buttonStyle(SlabStyle())
    }
}

struct TextAction: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .buttonStyle(TextActionStyle())
    }
}

struct ButtonLabel: View {
    let title: String
    let systemImage: String?
    let weight: Theme.Sans

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(Theme.sans(13.5, weight))
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 12.5, weight: .semibold))
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }
}

private struct SlabStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(enabled ? Theme.page : Theme.faint)
            .background(enabled ? Theme.text : Theme.line2, in: RoundedRectangle(cornerRadius: Theme.radius))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct TextActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Hovered(pressed: configuration.isPressed) {
            configuration.label
        }
    }

    private struct Hovered<Label: View>: View {
        let pressed: Bool
        @ViewBuilder let label: Label
        @State private var hovering = false

        var body: some View {
            label
                .font(Theme.mono(12.5))
                .foregroundStyle(hovering || pressed ? Theme.text : Theme.dim)
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }
    }
}
