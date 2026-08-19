import AppKit
import Observation

/// Registers the embedded screen saver extension with pluginkit and tracks
/// the pieces of system state the UI shows.
@MainActor
@Observable
final class ExtensionRegistrar {
    private(set) var isRegistered = false
    private(set) var legacySaverExists = false

    private let extensionIdentifier = "dev.nozomiishii.brooklyn.extension"

    private var embeddedExtensionURL: URL? {
        Bundle.main.builtInPlugInsURL?.appendingPathComponent("BrooklynExtension.appex")
    }

    /// The pre-1.2 Brooklyn was a .saver bundle here. It keeps working through
    /// legacyScreenSaver but shadows this version in System Settings.
    private var legacySaverURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Screen Savers/Brooklyn.saver")
    }

    /// Placement in /Applications alone is not always picked up until the next
    /// LaunchServices scan, so launching the app registers explicitly and
    /// elects the extension for use.
    func registerAndRefresh() {
        if let url = embeddedExtensionURL {
            _ = runPluginKit(["-a", url.path])
            _ = runPluginKit(["-e", "use", "-i", extensionIdentifier])
        }
        refresh()
    }

    func refresh() {
        let output = runPluginKit(["-m", "-v", "-i", extensionIdentifier])
        isRegistered = output.contains(extensionIdentifier)
        legacySaverExists = FileManager.default.fileExists(atPath: legacySaverURL.path)
    }

    func removeLegacySaver() {
        try? FileManager.default.removeItem(at: legacySaverURL)
        refresh()
    }

    func openScreenSaverSettings() {
        // The Screen Saver pane lives inside Wallpaper settings on macOS 26.
        if let url = URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private func runPluginKit(_ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
