import SwiftUI

struct RootView: View {
    let model: CurfewModel

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                ScreenView(model: model)
                    .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollIndicators(.automatic)
        }
        .background(Theme.page)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
    }
}

struct ScreenView: View {
    let model: CurfewModel

    var body: some View {
        switch (model.screen, model.stage) {
        case (.about, _): AboutView(model: model)
        case (.home, .setup): FirstRunView(model: model)
        case (.home, _): MainView(model: model)
        }
    }
}
