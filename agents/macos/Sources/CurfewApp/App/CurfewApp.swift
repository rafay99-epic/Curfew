import AppKit
import SwiftUI

struct CurfewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = CurfewModel.live()

    init() {
        AppResources.registerFonts()
    }

    var body: some Scene {
        Window("Curfew", id: "main") {
            RootView(model: model)
                .frame(minWidth: 480, minHeight: 460)
                .background(WindowChrome())
                .task { await model.refresh() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task { await model.refresh() }
                }
        }
        .defaultSize(width: 560, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ChromeView()
    }

    func updateNSView(_ view: NSView, context: Context) {}

    private final class ChromeView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.backgroundColor = .black
            window.titlebarAppearsTransparent = true
            window.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
