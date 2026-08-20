import AppKit
import SwiftUI

/// Host app for the Brooklyn screen saver extension.
///
/// The saver itself is Contents/PlugIns/BrooklynExtension.appex; System
/// Settings runs it as its own process. This app exists to keep the extension
/// at a stable path, register it with pluginkit on launch, and offer setup
/// shortcuts.
@main
struct BrooklynApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Brooklyn", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Registration runs from the launch path, not the window content, so it
    /// happens even when the app is launched without showing its window.
    func applicationDidFinishLaunching(_: Notification) {
        Task { @MainActor in
            AppIconController.shared.restoreOnLaunch()
            await ExtensionRegistrar.shared.registerAndRefresh()
        }
    }

    /// Quits when the window closes; the app has no background role.
    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }
}
