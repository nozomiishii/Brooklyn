import AVFoundation

/// An AVQueuePlayer that loops through a playlist, rebuilding the full
/// cycle each time it completes.
///
/// When `makePlaylist` is provided, the player rebuilds the playlist at the
/// end of each cycle (re-shuffling if needed). Otherwise, it falls back to
/// simple item-by-item looping.
final class LoopPlayer: AVQueuePlayer {
    nonisolated(unsafe) private var itemDidFinishObserver: NSObjectProtocol?
    private var makePlaylist: (() -> [AVPlayerItem])?
    private var remainingInCycle: Int = 0

    override init() {
        super.init()
    }

    /// Initialize with a playlist factory that produces a full cycle of items.
    /// At the end of each cycle, the factory is called again to rebuild the queue.
    init(makePlaylist: @escaping () -> [AVPlayerItem]) {
        self.makePlaylist = makePlaylist
        let items = makePlaylist()
        var queue = items
        if queue.count == 1, let copy = queue.first?.copy() as? AVPlayerItem {
            queue.append(copy)
        }
        super.init(items: queue)
        self.remainingInCycle = queue.count
        setupCycleObserver()
    }

    /// Initialize with a fixed list of items that loop individually.
    override init(items: [AVPlayerItem]) {
        var queue = items
        if queue.count == 1, let copy = queue.first?.copy() as? AVPlayerItem {
            queue.append(copy)
        }
        super.init(items: queue)
        setupSimpleLoopObserver()
    }

    private func setupCycleObserver() {
        itemDidFinishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let makePlaylist = self.makePlaylist else { return }
            self.remainingInCycle -= 1
            if self.remainingInCycle <= 0 {
                let newItems = makePlaylist()
                for item in newItems {
                    self.insert(item, after: nil)
                }
                self.remainingInCycle = newItems.count
            }
        }
    }

    private func setupSimpleLoopObserver() {
        itemDidFinishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let finishedItem = notification.object as? AVPlayerItem,
                  let copy = finishedItem.copy() as? AVPlayerItem
            else { return }
            self.insert(copy, after: nil)
        }
    }

    /// Play a single item (used for preview in the configuration sheet).
    func playPreview(_ item: AVPlayerItem) {
        removeAllItems()
        insert(item, after: nil)
        seek(to: .zero)
        play()
    }

    func tearDown() {
        pause()
        if let observer = itemDidFinishObserver {
            NotificationCenter.default.removeObserver(observer)
            itemDidFinishObserver = nil
        }
        removeAllItems()
    }

    deinit {
        if let observer = itemDidFinishObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
