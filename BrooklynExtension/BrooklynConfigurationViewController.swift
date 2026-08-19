import AppKit
import os
import SwiftUI

private let logger = Logger(subsystem: "dev.nozomiishii.brooklyn.extension", category: "Configuration")

/// Configuration sheet shown when the user clicks "Options…" in System Settings.
/// Referenced from Info.plist as ScreenSaverConfigurationSheetViewControllerClass.
///
/// Hosts the SwiftUI ConfigureSheet. The ViewBridge remote sheet only renders
/// this arrangement: NSHostingController added as a child, its view pinned
/// inside a plain container view. A bare NSHostingView, or assigning the
/// hosting controller's view as self.view directly, stays blank.
@objc(BrooklynConfigurationViewController)
final class BrooklynConfigurationViewController: ScreenSaverConfigurationViewController {
    override func loadView() {
        logger.info("loadView()")

        let manager = BrooklynManager(bundle: Bundle(for: BrooklynView.self))
        let sheet = ConfigureSheet(manager: manager) { [weak self] in
            self?.dismissSheet()
        }
        let hosting = NSHostingController(rootView: sheet)
        addChild(hosting)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 560))
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        view = container
        preferredContentSize = NSSize(width: 480, height: 560)
    }

    /// The sheet is a remote ViewBridge scene owned by System Settings.
    /// sheetParent, presentingViewController, and NSApp.keyWindow are all nil
    /// here; configureSheetDidEnd is what closes the sheet.
    private func dismissSheet() {
        logger.info("dismissSheet()")
        configureSheetDidEnd()
    }
}
