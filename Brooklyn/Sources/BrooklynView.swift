import AVFoundation
import ScreenSaver

/// The main screen saver view that plays Brooklyn animations.
///
/// Handles the macOS Sonoma+ bugs:
/// - `stopAnimation()` not being called → listens for `com.apple.screensaver.willstop`
/// - Instance accumulation → lame-duck pattern via `newInstanceCreated` notification
/// - `isPreview` always returning true → frame size heuristic
final class BrooklynView: ScreenSaverView {
    /// Tracks active instances per screen to handle the Sonoma+ instance accumulation bug.
    /// Key is the screen's deviceDescription identifier.
    private static var activeInstances: [UInt32: BrooklynView] = [:]

    private var manager: BrooklynManager?
    private var player: LoopPlayer?
    private var playerLayer: AVPlayerLayer?
    private var configureSheetController: ConfigureSheetController?
    nonisolated(unsafe) private var screenID: UInt32 = 0
    private var isLameDuck = false
    nonisolated(unsafe) private var willStopObserver: NSObjectProtocol?

    // MARK: - Initialization

    override init?(frame: NSRect, isPreview: Bool) {
        // Workaround: isPreview is broken on Sonoma+. Use frame size heuristic.
        let actualIsPreview = frame.width < 400 && frame.height < 300
        super.init(frame: frame, isPreview: actualIsPreview)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.0, green: 0.01, blue: 0.0, alpha: 1.0).cgColor
        animationTimeInterval = 1.0 / 30.0

        let bundle = Bundle(for: BrooklynView.self)
        manager = BrooklynManager(bundle: bundle)

        // Determine which screen this view belongs to.
        if let screenNumber = window?.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 {
            screenID = screenNumber
        }

        // Shut down any previous instance on the same screen (Sonoma+ bug workaround).
        if let oldInstance = Self.activeInstances[screenID], oldInstance !== self {
            oldInstance.goLameDuck()
        }
        Self.activeInstances[screenID] = self

        setupPlayer()
        observeLifecycle()
    }

    private func setupPlayer() {
        guard let manager else { return }

        let items = manager.makePlayerItems()
        let loopPlayer = LoopPlayer(items: items)
        loopPlayer.isMuted = true

        let layer = AVPlayerLayer(player: loopPlayer)
        layer.frame = bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer.videoGravity = .resizeAspect
        self.layer?.addSublayer(layer)

        self.player = loopPlayer
        self.playerLayer = layer
    }

    // MARK: - Lifecycle Workarounds

    private func observeLifecycle() {
        // Sonoma+: stopAnimation() is not called. Listen for willstop instead.
        willStopObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screensaver.willstop"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillStop()
        }
    }

    private func handleWillStop() {
        player?.tearDown()
        playerLayer?.removeFromSuperlayer()
        removeObservers()
    }

    private func goLameDuck() {
        guard !isLameDuck else { return }
        isLameDuck = true
        player?.tearDown()
        playerLayer?.removeFromSuperlayer()
        removeObservers()
    }

    private func removeObservers() {
        if let observer = willStopObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            willStopObserver = nil
        }
    }

    // MARK: - ScreenSaverView Overrides

    override func startAnimation() {
        super.startAnimation()
        guard !isLameDuck else { return }
        player?.play()
    }

    override func stopAnimation() {
        super.stopAnimation()
        player?.pause()
    }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        playerLayer?.frame = bounds
    }

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        guard let manager else { return nil }
        if configureSheetController == nil {
            let sheet = ConfigureSheet(manager: manager)
            configureSheetController = ConfigureSheetController(rootView: sheet)
        }
        return configureSheetController?.window
    }

    // MARK: - Drawing

    override func draw(_ rect: NSRect) {
        NSColor(red: 0.0, green: 0.01, blue: 0.0, alpha: 1.0).setFill()
        rect.fill()
    }

    deinit {
        if let observer = willStopObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        if Self.activeInstances[screenID] === self {
            Self.activeInstances.removeValue(forKey: screenID)
        }
    }
}
