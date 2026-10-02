import SwiftUI

struct Page<Content: View, Actions: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
            Spacer(minLength: 28)
            HStack(spacing: 10) {
                actions
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, Theme.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
