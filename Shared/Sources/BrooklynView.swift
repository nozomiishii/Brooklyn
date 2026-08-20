import AVFoundation
import ScreenSaver

/// The main screen saver view that plays Brooklyn animations.
///
/// Runs inside BrooklynExtension.appex, driven by BrooklynViewController.
/// Defensive behaviors that stay even in the appex world:
/// - `startAnimation()`/`stopAnimation()` are not reliably called on the view →
///   the view controller drives them; `com.apple.screensaver.willstop` stays
///   as a second stop path (pause only — the framework reuses live instances,
///   so stopping must never leave the view unable to start again)
/// - The player is built lazily on the first `startAnimation()`, so degenerate
///   instances that never appear (zero-size instances seen in System Settings
///   preview machinery) never load the 75 player items, and a torn-down
///   player can be rebuilt on the next start
final class BrooklynView: ScreenSaverView {
    private var player: LoopPlayer?
    private var playerLayer: AVPlayerLayer?
    private var isAnimationStarted = false
    private nonisolated(unsafe) var willStopObserver: NSObjectProtocol?

    // MARK: - Initialization

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)

        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.0, green: 0.01, blue: 0.0, alpha: 1.0).cgColor

        observeLifecycle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setupPlayerIfNeeded() {
        guard player == nil, frame != .zero else { return }

        let manager = BrooklynManager(bundle: Bundle(for: BrooklynView.self))
        let loopPlayer = LoopPlayer(items: manager.makePlayerItems())
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
                self?.stopAnimation()
            }
        }
    }

    // MARK: - ScreenSaverView Overrides

    override func startAnimation() {
        guard !isAnimationStarted else { return }
        super.startAnimation()
        isAnimationStarted = true
        setupPlayerIfNeeded()
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
