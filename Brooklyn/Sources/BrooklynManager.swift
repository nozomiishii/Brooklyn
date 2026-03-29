import AVFoundation

/// Central manager that coordinates animation selection, preferences, and playback.
@MainActor
final class BrooklynManager {
    let database: Database
    private let bundle: Bundle

    init(bundle: Bundle) {
        self.bundle = bundle
        self.database = Database(moduleBundle: bundle)
    }

    // MARK: - Animation Selection

    var selectedAnimations: [Animation] {
        database.selectedAnimations
    }

    func isSelected(_ animation: Animation) -> Bool {
        database.selectedAnimations.contains(animation)
    }

    func toggle(_ animation: Animation) {
        var selected = database.selectedAnimations
        if let index = selected.firstIndex(of: animation) {
            if selected.count > 1 {
                selected.remove(at: index)
            }
        } else {
            selected.append(animation)
        }
        database.selectedAnimations = selected
    }

    func selectAll() {
        database.selectedAnimations = Animation.allCases
    }

    func removeAll() {
        database.selectedAnimations = [Animation.allCases.first!]
    }

    // MARK: - Playback

    func makePlayerItems() -> [AVPlayerItem] {
        let selected = database.selectedAnimations
        let hasOriginal = selected.contains(.original)

        // Separate original from the rest
        var rest = selected.filter { $0 != .original }
        if database.randomOrder {
            rest.shuffle()
        }

        let loops = database.numberOfLoops + 1

        var items: [AVPlayerItem] = []

        // Play original first if selected
        if hasOriginal, let url = Animation.original.videoURL(in: bundle) {
            items.append(AVPlayerItem(url: url))
        }

        // Then play the rest
        items += rest.flatMap { animation -> [AVPlayerItem] in
            (0..<loops).compactMap { _ in
                guard let url = animation.videoURL(in: bundle) else { return nil }
                return AVPlayerItem(url: url)
            }
        }

        return items
    }

    func makePreviewItem(for animation: Animation) -> AVPlayerItem? {
        guard let url = animation.videoURL(in: bundle) else { return nil }
        return AVPlayerItem(url: url)
    }
}
