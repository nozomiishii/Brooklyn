import AVFoundation
import XCTest

/// Tests for BrooklynManager's playback logic.
/// Regression areas:
/// - Original must play first when selected
/// - Customize OFF must use all animations (not stale saved preferences)
/// - makePlayerItems must never return empty (caused black screen)
@MainActor
final class BrooklynManagerTests: XCTestCase {
    private var manager: BrooklynManager!

    override func setUp() {
        super.setUp()
        let bundle = Bundle(for: type(of: self))
        manager = BrooklynManager(bundle: bundle)
        // Reset to defaults
        manager.selectAll()
        manager.database.customize = false
        manager.database.randomOrder = false
        manager.database.numberOfLoops = 0
    }

    // MARK: - Player Items Must Never Be Empty

    func testMakePlayerItemsNeverReturnsEmpty() {
        let items = manager.makePlayerItems()
        XCTAssertFalse(items.isEmpty, "makePlayerItems must never return empty — causes black screen")
    }

    func testMakePlayerItemsWithCustomizeOffUsesAllAnimations() {
        manager.database.customize = false
        // Even if saved selection is just one animation
        manager.database.selectedAnimations = [.appleBits]

        let items = manager.makePlayerItems()
        // Should use ALL animations, not saved selection
        XCTAssertEqual(items.count, Animation.allCases.count,
                       "Customize OFF must use all animations regardless of saved selection")
    }

    func testMakePlayerItemsWithCustomizeOnUsesSavedSelection() {
        manager.database.customize = true
        manager.database.selectedAnimations = [.appleBits, .ballPit]
        manager.database.randomOrder = false

        let items = manager.makePlayerItems()
        XCTAssertEqual(items.count, 2)
    }

    // MARK: - Original Plays First

    func testOriginalPlaysFirstWhenSelected() {
        manager.database.customize = false
        manager.database.randomOrder = false

        let items = manager.makePlayerItems()
        guard let firstItem = items.first,
              let firstURL = (firstItem.asset as? AVURLAsset)?.url
        else {
            XCTFail("First item must have a URL")
            return
        }

        XCTAssertTrue(
            firstURL.lastPathComponent == "original.mp4",
            "First item must be original.mp4, got \(firstURL.lastPathComponent)"
        )
    }

    func testOriginalIsExcludedFromRestOfPlaylist() {
        manager.database.customize = false
        manager.database.randomOrder = false

        let items = manager.makePlayerItems()
        let originalCount = items.count { item in
            guard let url = (item.asset as? AVURLAsset)?.url else { return false }
            return url.lastPathComponent == "original.mp4"
        }

        XCTAssertEqual(originalCount, 1, "Original should appear exactly once (at the start)")
    }

    func testOriginalNotIncludedWhenNotSelected() {
        manager.database.customize = true
        manager.database.selectedAnimations = [.appleBits, .ballPit]
        manager.database.randomOrder = false

        let items = manager.makePlayerItems()
        let hasOriginal = items.contains { item in
            (item.asset as? AVURLAsset)?.url?.lastPathComponent == "original.mp4"
        }

        XCTAssertFalse(hasOriginal, "Original should not be in playlist when not selected")
    }

    // MARK: - Animation Selection

    func testToggleAddsAnimation() {
        manager.database.selectedAnimations = [.original]
        manager.toggle(.appleBits)
        XCTAssertTrue(manager.isSelected(.appleBits))
    }

    func testToggleRemovesAnimation() {
        manager.database.selectedAnimations = [.original, .appleBits]
        manager.toggle(.appleBits)
        XCTAssertFalse(manager.isSelected(.appleBits))
    }

    func testToggleKeepsAtLeastOneSelected() {
        manager.database.selectedAnimations = [.original]
        manager.toggle(.original)
        XCTAssertEqual(manager.selectedAnimations.count, 1,
                       "Must keep at least one animation selected")
    }

    func testSelectAll() {
        manager.database.selectedAnimations = [.original]
        manager.selectAll()
        XCTAssertEqual(manager.selectedAnimations.count, Animation.allCases.count)
    }

    func testRemoveAllKeepsOne() {
        manager.selectAll()
        manager.removeAll()
        XCTAssertEqual(manager.selectedAnimations.count, 1,
                       "removeAll must keep at least one animation")
    }

    // MARK: - Loops

    func testLoopsMultipliesItems() {
        manager.database.customize = true
        manager.database.selectedAnimations = [.appleBits]
        manager.database.numberOfLoops = 2 // means 3 plays

        let items = manager.makePlayerItems()
        XCTAssertEqual(items.count, 3, "numberOfLoops=2 means each animation plays 3 times")
    }

    func testCustomizeOffIgnoresLoopsSetting() {
        manager.database.customize = false
        manager.database.numberOfLoops = 5

        let items = manager.makePlayerItems()
        // Should be 75 items (all animations × 1 loop), not 75 × 6
        XCTAssertEqual(items.count, Animation.allCases.count)
    }
}
