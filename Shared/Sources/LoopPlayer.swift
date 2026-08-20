import AVFoundation

/// An AVQueuePlayer that endlessly loops through a list of video items.
///
/// When an item finishes playing, it is copied and re-appended to the queue,
/// creating an infinite loop effect.
final class LoopPlayer: AVQueuePlayer {
    private nonisolated(unsafe) var itemDidFinishObserver: NSObjectProtocol?
    /// Items this player owns. AVPlayerItemDidPlayToEndTime is observed with
    /// object: nil (the finished item is already dequeued by the time the
    /// notification arrives, so it can't be matched against items()), and the
    /// appex runs one player per display in a single process — without this
    /// filter every player re-enqueues every other player's finished items and
    /// queues grow without bound. Accessed on the main queue only.
    private nonisolated(unsafe) var ownedItems = Set<ObjectIdentifier>()

    override init() {
        super.init()
        itemDidFinishObserver = makeObserver()
    }

    override init(items: [AVPlayerItem]) {
        var queue = items
        // AVQueuePlayer needs at least 2 items to loop properly.
        if queue.count == 1, let copy = queue.first?.copy() as? AVPlayerItem {
            queue.append(copy)
        }
        super.init(items: queue)
        ownedItems = Set(queue.map { ObjectIdentifier($0) })
        itemDidFinishObserver = makeObserver()
    }

    private nonisolated func makeObserver() -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let finishedItem = notification.object as? AVPlayerItem else { return }
            MainActor.assumeIsolated {
                guard self.ownedItems.remove(ObjectIdentifier(finishedItem)) != nil,
                      let copy = finishedItem.copy() as? AVPlayerItem
                else { return }
                self.ownedItems.insert(ObjectIdentifier(copy))
                self.insert(copy, after: nil)
            }
        }
    }

    /// Play a single item (used for preview in the configuration sheet).
    func playPreview(_ item: AVPlayerItem) {
        removeAllItems()
        ownedItems = [ObjectIdentifier(item)]
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
        ownedItems.removeAll()
    }

    deinit {
        if let observer = itemDidFinishObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
