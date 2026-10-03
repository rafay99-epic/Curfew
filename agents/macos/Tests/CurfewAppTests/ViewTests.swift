@testable import CurfewApp
import CoreImage
import SwiftUI
import Testing

@MainActor
@Suite struct ViewTests {
    @Test func renderedQRCodeScansBackToTheLink() throws {
        let link = Snapshots.offer.uri
        let renderer = ImageRenderer(content: QRCodeView(link).frame(width: 200, height: 200).padding(20).background(Color.black))
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        let detector = try #require(CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil))
        let found = detector.features(in: CIImage(cgImage: image)).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
        #expect(found == [link])
    }

    @Test func phoneCountsReadAsWords() {
        #expect(MainView.count(1) == "One phone")
        #expect(MainView.count(2) == "Two phones")
        #expect(MainView.count(12) == "12 phones")
    }

    @Test func countdownClock() {
        #expect(PairingView.clock(102) == "1:42")
        #expect(PairingView.clock(9) == "0:09")
        #expect(PairingView.clock(-3) == "0:00")
    }

    @Test func everySnapshotRenders() {
        AppResources.registerFonts()
        for (name, model) in Snapshots.pages {
            #expect(Snapshots.image(ScreenView(model: model).background(Theme.page), scale: 1) != nil, "\(name)")
        }
    }

    @Test func fontsAndLicencesShipFromOneFolder() throws {
        let fonts = try FileManager.default.contentsOfDirectory(atPath: AppResources.fonts.path).sorted()
        #expect(fonts == ["Geist.ttf", "GeistMono.ttf", "InstrumentSerif.ttf"])
        #expect(AboutView.licenceText.contains("SIL OPEN FONT LICENSE"))
    }
}
