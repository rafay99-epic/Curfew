import SwiftUI

enum Theme {
    static let page = Color.black
    static let text = Color.white
    static let lede = Color(white: 0xE8 / 255)
    static let dim = Color(white: 0xB4 / 255)
    static let faint = Color(white: 0x6E / 255)
    static let line = Color(white: 0x1C / 255)
    static let line2 = Color(white: 0x33 / 255)

    static let gutter: CGFloat = 30
    static let top: CGFloat = 26
    static let radius: CGFloat = 10

    enum Sans: String {
        case regular = "Geist-Regular"
        case medium = "Geist-Medium"
        case semibold = "Geist-SemiBold"
    }

    enum Mono: String {
        case regular = "GeistMono-Regular"
        case medium = "GeistMono-Medium"
    }

    static func serif(_ size: CGFloat) -> Font {
        .custom("InstrumentSerif-Regular", fixedSize: size)
    }

    static func sans(_ size: CGFloat, _ weight: Sans = .regular) -> Font {
        .custom(weight.rawValue, fixedSize: size)
    }

    static func mono(_ size: CGFloat, _ weight: Mono = .regular) -> Font {
        .custom(weight.rawValue, fixedSize: size)
    }
}
