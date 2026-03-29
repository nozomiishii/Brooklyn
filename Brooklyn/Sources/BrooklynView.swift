import AVFoundation
import ScreenSaver

/// The main screen saver view that plays Brooklyn animations.
///
/// Handles the macOS Sonoma+ bugs:
/// - `stopAnimation()` not being called → listens for `com.apple.screensaver.willstop`
/// - `isPreview` always returning true → frame size heuristic
final class BrooklynView: ScreenSaverView {
    private var manager: BrooklynManager?
    private var player: LoopPlayer?
    private var playerLayer: AVPlayerLayer?
    private var configureSheetController: ConfigureSheetController?
    nonisolated(unsafe) private var willStopObserver: NSObjectProtocol?

    // MARK: - Initialization

    override init?(frame: NSRect, isPreview: Bool) {
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

    // MARK: - Lifecycle

    private func observeLifecycle() {
        willStopObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screensaver.willstop"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cleanUp()
        }
    }

    private func cleanUp() {
        player?.tearDown()
        playerLayer?.removeFromSuperlayer()
        if let observer = willStopObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            willStopObserver = nil
        }
    }

    // MARK: - ScreenSaverView Overrides

    override func startAnimation() {
        super.startAnimation()
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

    override func draw(_ rect: NSRect) {
        NSColor(red: 0.0, green: 0.01, blue: 0.0, alpha: 1.0).setFill()
        rect.fill()
    }

    deinit {
        if let observer = willStopObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
}
