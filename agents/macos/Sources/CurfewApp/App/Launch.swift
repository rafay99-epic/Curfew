import Foundation

@main
@MainActor
enum Launch {
    static func main() {
        #if DEBUG
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--render-snapshots"), arguments.indices.contains(flag + 1) {
            do {
                try Snapshots.render(into: URL(fileURLWithPath: arguments[flag + 1], isDirectory: true))
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("snapshots failed: \(error)\n".utf8))
                exit(1)
            }
        }
        if let flag = arguments.firstIndex(of: "--render-icon"), arguments.indices.contains(flag + 1) {
            do {
                try Snapshots.write(IconArt(), to: URL(fileURLWithPath: arguments[flag + 1]), size: CGSize(width: 1024, height: 1024), scale: 1)
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("icon failed: \(error)\n".utf8))
                exit(1)
            }
        }
        #endif
        CurfewApp.main()
    }
}
