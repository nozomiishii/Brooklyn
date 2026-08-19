import AVFoundation
import ScreenSaver

/// The main screen saver view that plays Brooklyn animations.
///
/// Runs inside BrooklynExtension.appex, driven by BrooklynViewController.
/// Defensive behaviors that stay even in the appex world:
/// - `isPreview` is not passed in by the system → frame size heuristic
/// - `startAnimation()`/`stopAnimation()` are not reliably called on the view →
///   the view controller drives them; `com.apple.screensaver.willstop` stays
///   as a second cleanup path
/// - Degenerate zero-frame instances (seen in System Settings preview
///   machinery) → skip player setup to avoid loading 75 player items
final class BrooklynView: ScreenSaverView {
    private var manager: BrooklynManager?
    private var player: LoopPlayer?
    private var playerLayer: AVPlayerLayer?
    private var isAnimationStarted = false
    private nonisolated(unsafe) var willStopObserver: NSObjectProtocol?

    // MARK: - Initialization

    override init?(frame: NSRect, isPreview _: Bool) {
        let actualIsPreview = frame.width < 400 && frame.height < 300
        super.init(frame: frame, isPreview: actualIsPreview)

        manager = BrooklynManager(bundle: Bundle(for: BrooklynView.self))

        // Skip visual/player setup on degenerate instances to avoid wasting resources.
        if frame == .zero {
            return
        }

        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.0, green: 0.01, blue: 0.0, alpha: 1.0).cgColor
        animationTimeInterval = 1.0 / 30.0

        setupPlayer()
        observeLifecycle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
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

        player = loopPlayer
        playerLayer = layer
    }

    // MARK: - Lifecycle

    private func observeLifecycle() {
        willStopObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screensaver.willstop"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.cleanUp()
            }
        }
    }

    private func cleanUp() {
        if isAnimationStarted {
            stopAnimation()
        }
        player?.tearDown()
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        if let observer = willStopObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            willStopObserver = nil
        }
    }

    // MARK: - ScreenSaverView Overrides

    override func startAnimation() {
        guard !isAnimationStarted, player != nil else { return }
        super.startAnimation()
        isAnimationStarted = true
        player?.play()
    }

    override func stopAnimation() {
        guard isAnimationStarted else { return }
        super.stopAnimation()
        isAnimationStarted = false
        player?.pause()
    }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        playerLayer?.frame = bounds
    }

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
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
