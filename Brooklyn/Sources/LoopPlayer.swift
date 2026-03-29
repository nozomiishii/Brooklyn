import AVFoundation

/// An AVQueuePlayer that endlessly loops through a list of video items.
///
/// When an item finishes playing, it is copied and re-appended to the queue,
/// creating an infinite loop effect.
final class LoopPlayer: AVQueuePlayer {
    nonisolated(unsafe) private var itemDidFinishObserver: NSObjectProtocol?

    override init() {
        super.init()
        setupObserver()
    }

    override init(items: [AVPlayerItem]) {
        var queue = items
        // AVQueuePlayer needs at least 2 items to loop properly.
        if queue.count == 1, let copy = queue.first?.copy() as? AVPlayerItem {
            queue.append(copy)
        }
        super.init(items: queue)
        setupObserver()
    }

    private func setupObserver() {
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
