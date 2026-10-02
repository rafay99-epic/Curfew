import CoreText
import Foundation

enum AppResources {
    static var directory: URL {
        if let bundled = Bundle.main.resourceURL, FileManager.default.fileExists(atPath: bundled.appending(path: "Fonts").path) {
            return bundled
        }
        #if DEBUG
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Resources")
        #else
        return Bundle.main.bundleURL
        #endif
    }

    static var fonts: URL { directory.appending(path: "Fonts") }
    static var licences: URL { directory.appending(path: "Licenses") }

    static func registerFonts() {
        let files = (try? FileManager.default.contentsOfDirectory(at: fonts, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
        }
    }
}
