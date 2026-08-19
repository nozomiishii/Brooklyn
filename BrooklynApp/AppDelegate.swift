import AppKit

/// Host app for the Brooklyn screen saver extension.
///
/// The saver itself is Contents/PlugIns/BrooklynExtension.appex; System
/// Settings runs it as its own process. This app exists to keep the extension
/// at a stable path, register it with pluginkit on first launch, and offer
/// setup shortcuts.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var statusLabel: NSTextField?
    private var legacyCleanupButton: NSButton?

    private let extensionIdentifier = "dev.nozomiishii.brooklyn.extension"

    private var embeddedExtensionURL: URL? {
        Bundle.main.builtInPlugInsURL?.appendingPathComponent("BrooklynExtension.appex")
    }

    private var legacySaverURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Screen Savers/Brooklyn.saver")
    }

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        buildWindow()
        registerExtension()
        refreshStatus()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }

    // MARK: - UI

    private func buildWindow() {
        let title = NSTextField(labelWithString: "Brooklyn")
        title.font = NSFont.systemFont(ofSize: 24, weight: .bold)

        let subtitle = NSTextField(
            wrappingLabelWithString: """
            Select Brooklyn in System Settings > Wallpaper > Screen Saver.
            The screen saver extension is registered automatically when this app launches.
            """
        )
        subtitle.font = NSFont.systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        let status = NSTextField(labelWithString: "")
        status.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        status.textColor = .secondaryLabelColor
        statusLabel = status

        let settingsButton = NSButton(
            title: "Open Screen Saver Settings", target: self, action: #selector(openSettings)
        )
        settingsButton.keyEquivalent = "\r"

        let registerButton = NSButton(
            title: "Re-register Extension", target: self, action: #selector(reregister)
        )

        let cleanupButton = NSButton(
            title: "Remove Legacy Brooklyn.saver", target: self, action: #selector(removeLegacySaver)
        )
        legacyCleanupButton = cleanupButton

        let stack = NSStackView(views: [title, subtitle, status, settingsButton, registerButton, cleanupButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 280),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Brooklyn"
        window.contentView = stack
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private func refreshStatus() {
        let output = runPluginKit(["-m", "-v", "-i", extensionIdentifier])
        let registered = output.contains(extensionIdentifier)
        statusLabel?.stringValue = registered
            ? "Extension registered (\(extensionIdentifier))"
            : "Extension not registered yet"
        legacyCleanupButton?.isHidden = !FileManager.default.fileExists(atPath: legacySaverURL.path)
    }

    // MARK: - Actions

    /// Register the embedded extension and elect it for use. Placement in
    /// /Applications alone is not always picked up until the next
    /// LaunchServices scan, so launching this app guarantees registration.
    private func registerExtension() {
        guard let url = embeddedExtensionURL else { return }
        _ = runPluginKit(["-a", url.path])
        _ = runPluginKit(["-e", "use", "-i", extensionIdentifier])
    }

    @objc private func reregister() {
        registerExtension()
        refreshStatus()
    }

    @objc private func openSettings() {
        // The Screen Saver pane lives inside Wallpaper settings on macOS 26.
        if let url = URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// The pre-1.2 Brooklyn was a .saver bundle in ~/Library/Screen Savers.
    /// It keeps working through legacyScreenSaver but shadows this version in
    /// System Settings, so offer a one-click removal.
    @objc private func removeLegacySaver() {
        try? FileManager.default.removeItem(at: legacySaverURL)
        refreshStatus()
    }

    // MARK: - Helpers

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
