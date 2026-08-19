import AppKit
import os
import ScreenSaver

private let logger = Logger(subsystem: "dev.nozomiishii.brooklyn.extension", category: "ViewController")

/// Main view controller of the screen saver app extension.
/// Referenced from Info.plist as ScreenSaverViewControllerClass.
///
/// Wraps BrooklynView. startAnimation/stopAnimation are not reliably called
/// on the view by the framework in the appex world, but the view controller
/// lifecycle is: viewDidAppear/viewWillDisappear fire on every start and stop
/// (verified on macOS 26), so playback is driven from here.
@objc(BrooklynViewController)
final class BrooklynViewController: ScreenSaverViewController {
    /// Strong reference so the framework can't drop the view while we own it.
    private var saverView: BrooklynView?

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func loadView() {
        // No frame is handed in; mirror Apple's own savers and size to the
        // main screen. Preview surfaces resize the view afterwards.
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        logger.info("loadView() screenFrame=\(String(describing: frame), privacy: .public)")

        let view = BrooklynView(frame: frame, isPreview: frame.width < 400)
        saverView = view
        self.view = view ?? NSView(frame: frame)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        let bounds = String(describing: view.bounds)
        logger.info("viewDidAppear() bounds=\(bounds, privacy: .public)")
        saverView?.startAnimation()
    }

    override func viewWillDisappear() {
        logger.info("viewWillDisappear()")
        saverView?.stopAnimation()
        super.viewWillDisappear()
    }
}
