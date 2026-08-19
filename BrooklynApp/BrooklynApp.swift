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

/// Quits when the window closes; the app has no background role.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }
}
