import AppKit
import ScreenSaver

/// Debug application that hosts the BrooklynView without installing the screen saver.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var saverView: BrooklynView?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowFrame = NSRect(
            x: screenFrame.midX - 640,
            y: screenFrame.midY - 360,
            width: 1280,
            height: 720
        )

        let window = NSWindow(
            contentRect: windowFrame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Brooklyn Canvas"
        window.backgroundColor = .black

        if let view = BrooklynView(frame: windowFrame, isPreview: false) {
            window.contentView = view
            view.startAnimation()
            saverView = view
        }

        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_: Notification) {
        saverView?.stopAnimation()
    }
}
