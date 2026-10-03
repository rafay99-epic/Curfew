#if DEBUG
import AppKit
import CurfewControl
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum Snapshots {
    static let size = CGSize(width: 560, height: 600)
    static let phones = [
        ControlPhone(id: "a1b2c3d4e5f60718", name: "Rafay's Pixel", pairedAt: 1_790_000_000),
        ControlPhone(id: "0918273645aabbcc", name: "Work phone", pairedAt: 1_790_500_000),
    ]
    static let settings = ControlSettings(login: false, loginReady: true, wake: true, awake: false)
    static let offer = PairingOffer(address: "192.168.1.24:787", agent: "0b825f00961665a4", code: "K7PMQ2XR9DHA4FWE", expiresIn: 120)

    static var pages: [(String, CurfewModel)] {
        [
            ("first-run", .sample(.setup)),
            ("main", .sample(.running, phones: phones, settings: settings)),
            ("main-login", .sample(.running, phones: phones, settings: ControlSettings(login: true, loginReady: true, wake: true, awake: true))),
            ("update", .sample(.running, phones: phones, settings: settings, serviceVersion: "2.0.0")),
            ("pairing", .sample(.running, phones: phones, pairing: offer, secondsLeft: 102)),
            ("about", .sample(.running, phones: phones, screen: .about)),
            ("not-running", .sample(.stopped)),
        ]
    }

    static func render(into directory: URL) throws {
        _ = NSApplication.shared
        NSApp.appearance = NSAppearance(named: .darkAqua)
        AppResources.registerFonts()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, model) in pages {
            try write(ScreenView(model: model).background(Theme.page), to: directory.appending(path: name + ".png"))
        }
    }

    static func image(_ view: some View, size: CGSize = size, scale: CGFloat = 2) -> CGImage? {
        let renderer = ImageRenderer(content: view
            .frame(width: size.width, height: size.height, alignment: .top)
            .environment(\.colorScheme, .dark))
        renderer.scale = scale
        return renderer.cgImage
    }

    static func write(_ view: some View, to url: URL, size: CGSize = size, scale: CGFloat = 2) throws {
        guard let image = image(view, size: size, scale: scale),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
#endif
