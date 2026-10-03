import Foundation
import PackagePlugin

@main
struct VersionPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let input = context.package.directoryURL.appending(path: "VERSION")
        let output = context.pluginWorkDirectoryURL.appending(path: "CurfewVersion.swift")
        let script = #"read -r version < "$1"; printf 'public enum CurfewVersion {\n    public static let current = "%s"\n}\n' "$version" > "$2""#
        return [
            .buildCommand(
                displayName: "Version from VERSION",
                executable: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", script, "version", input.path, output.path],
                inputFiles: [input],
                outputFiles: [output]
            ),
        ]
    }
}
