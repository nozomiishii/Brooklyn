import AppKit
import Observation

/// Registers the embedded screen saver extension with pluginkit and tracks
/// the pieces of system state the UI shows.
///
/// One shared instance: registration is kicked from app launch (so it happens
/// even if the window never appears) and the UI observes the same state.
@MainActor
@Observable
final class ExtensionRegistrar {
    static let shared = ExtensionRegistrar()

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
    ///
    /// A registration can also point at a stale copy (a moved app, an old
    /// DerivedData build). WallpaperAgent caches the resolved path and then
    /// silently refuses selections, so a stale registration is dropped first
    /// and WallpaperAgent is restarted to flush the cache.
    func registerAndRefresh() async {
        guard let url = embeddedExtensionURL else { return }

        let staleRegistration: String?
        if let registered = await registeredPath(), registered != url.path {
            staleRegistration = registered
            _ = await Self.runPluginKit(["-r", registered])
        } else {
            staleRegistration = nil
        }

        _ = await Self.runPluginKit(["-a", url.path])
        _ = await Self.runPluginKit(["-e", "use", "-i", extensionIdentifier])

        if staleRegistration != nil {
            await Self.restartWallpaperAgent()
        }

        await refresh()
        if !isRegistered {
            // pkd may publish the registration asynchronously; check once more.
            try? await Task.sleep(for: .seconds(1))
            await refresh()
        }
    }

    func refresh() async {
        let registered = await registeredPath()
        isRegistered = registered != nil && registered == embeddedExtensionURL?.path
        legacySaverExists = FileManager.default.fileExists(atPath: legacySaverURL.path)
    }

    func removeLegacySaver() async {
        try? FileManager.default.removeItem(at: legacySaverURL)
        await refresh()
    }

    func openScreenSaverSettings() {
        // The Screen Saver pane lives inside Wallpaper settings on macOS 26.
        if let url = URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - pluginkit

    /// The path pluginkit currently resolves the extension to, or nil when
    /// unregistered. Line format: `+    <id>(<version>)\t<uuid>\t<date>\t<path>`.
    private func registeredPath() async -> String? {
        let output = await Self.runPluginKit(["-m", "-v", "-i", extensionIdentifier])
        guard let line = output.split(separator: "\n").first(where: { $0.contains(extensionIdentifier) }),
              let pathStart = line.firstIndex(of: "/")
        else { return nil }
        return String(line[pathStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Runs pluginkit off the main actor; the pipe is drained before waiting
    /// so a large output can never deadlock the wait.
    private nonisolated static func runPluginKit(_ arguments: [String]) async -> String {
        await runProcess("/usr/bin/pluginkit", arguments: arguments)
    }

    private nonisolated static func restartWallpaperAgent() async {
        _ = await runProcess("/usr/bin/killall", arguments: ["WallpaperAgent"])
    }

    private nonisolated static func runProcess(_ path: String, arguments: [String]) async -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
