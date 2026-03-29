import AppKit
import SwiftUI

/// Hosts the SwiftUI ConfigureSheet in an NSWindow for use with ScreenSaverView.configureSheet.
@MainActor
final class ConfigureSheetController: NSWindowController {
    convenience init(rootView: ConfigureSheet) {
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 480, height: 560)

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "Brooklyn Preferences"
        window.isReleasedWhenClosed = false

        self.init(window: window)
    }
}
