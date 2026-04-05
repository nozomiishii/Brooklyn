import AVFoundation
import XCTest

/// Tests for LoopPlayer.
/// Regression: AVQueuePlayer with a single item stops playing.
/// LoopPlayer must duplicate the item to keep the queue alive.
@MainActor
final class LoopPlayerTests: XCTestCase {
    func testSingleItemIsDuplicatedForLooping() {
        let bundle = Bundle(for: type(of: self))
        guard let url = Animation.appleBits.videoURL(in: bundle) else {
            XCTFail("appleBits.mp4 not found in test bundle")
            return
        }

        let item = AVPlayerItem(url: url)
        let player = LoopPlayer(items: [item])

        // AVQueuePlayer needs at least 2 items to loop
        XCTAssertGreaterThanOrEqual(
            player.items().count, 2,
            "Single item must be duplicated to prevent queue from stopping"
        )
    }

    func testMultipleItemsArePreserved() {
        let bundle = Bundle(for: type(of: self))
        guard let url1 = Animation.appleBits.videoURL(in: bundle),
              let url2 = Animation.ballPit.videoURL(in: bundle)
        else {
            XCTFail("MP4 files not found in test bundle")
            return
        }

        let items = [AVPlayerItem(url: url1), AVPlayerItem(url: url2)]
        let player = LoopPlayer(items: items)

        XCTAssertEqual(player.items().count, 2)
    }

    func testTearDownClearsQueue() {
        let bundle = Bundle(for: type(of: self))
        guard let url = Animation.appleBits.videoURL(in: bundle) else {
            XCTFail("appleBits.mp4 not found in test bundle")
            return
        }

        let player = LoopPlayer(items: [AVPlayerItem(url: url)])
        player.tearDown()

        XCTAssertTrue(player.items().isEmpty, "tearDown must clear all items")
        XCTAssertEqual(player.rate, 0, "tearDown must pause playback")
    }
}
