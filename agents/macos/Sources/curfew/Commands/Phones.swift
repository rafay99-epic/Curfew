import CurfewAgent
import CurfewProtocol
import Foundation

enum Phones {
    static func list(_ settings: Settings) async throws -> Int32 {
        let phones = try await settings.store.read().orderedPhones
        if phones.isEmpty {
            print("No phones are paired. Pair one with: sudo curfew pair")
        }
        let format = Date.FormatStyle().day(.twoDigits).month(.abbreviated).year(.defaultDigits).locale(Locale(identifier: "en_GB"))
        for (number, entry) in phones.enumerated() {
            let date = Date(timeIntervalSince1970: TimeInterval(entry.phone.added)).formatted(format)
            print("\(pad(String(number + 1), 2, right: true)). \(pad(entry.phone.name, 30)) paired \(date)")
        }
        return 0
    }

    static func unpair(_ settings: Settings, who: String) async throws -> Int32 {
        let now = Int(Wall.now())
        let removed = try await settings.store.update { state -> String? in
            let matches = state.orderedPhones.enumerated().filter { number, entry in
                who == String(number + 1) || entry.phone.name.lowercased() == who.lowercased()
            }
            guard matches.count == 1, let match = matches.first?.element else { return nil }
            return state.removePhone(match.id, now: now)?.name
        }
        guard let removed else {
            print("No phone called \"\(who)\". See the list with: sudo curfew phones")
            return 1
        }
        print("Removed \"\(removed)\". It can no longer control this computer.")
        return 0
    }

    static func pad(_ text: String, _ width: Int, right: Bool = false) -> String {
        let fill = String(repeating: " ", count: max(0, width - text.count))
        return right ? fill + text : text + fill
    }
}
