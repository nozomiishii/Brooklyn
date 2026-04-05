import XCTest

/// Tests for the Animation enum.
/// Regression: Animation enum raw values must match actual MP4 file names.
/// We originally had wrong names (annGreen, blueprintAMPM, etc.) that didn't
/// match the actual files (appleBits, auroraBorealis, etc.), causing silent
/// video load failures.
final class AnimationTests: XCTestCase {
    // MARK: - File Name Matching

    func testAllAnimationsHaveMatchingMP4Files() {
        let bundle = Bundle(for: type(of: self))
        for animation in Animation.allCases {
            let url = animation.videoURL(in: bundle)
            XCTAssertNotNil(
                url,
                "Missing MP4 file for animation '\(animation.rawValue)'. "
                    + "Ensure \(animation.rawValue).mp4 exists in Resources/Animations/"
            )
        }
    }

    func testAnimationCount() {
        XCTAssertEqual(Animation.allCases.count, 75, "Expected 75 animations")
    }

    func testOriginalAnimationExists() {
        XCTAssertNotNil(
            Animation(rawValue: "original"),
            "The 'original' animation must exist in the enum"
        )
    }

    // MARK: - Display Names

    func testDisplayNameFormatting() {
        XCTAssertEqual(Animation.appleBits.displayName, "Apple Bits")
        XCTAssertEqual(Animation.ballPit.displayName, "Ball Pit")
        XCTAssertEqual(Animation.original.displayName, "Original")
        XCTAssertEqual(Animation.cuphead2.displayName, "Cuphead 2")
    }

    // MARK: - Identifiable

    func testAllAnimationsHaveUniqueIDs() {
        let ids = Animation.allCases.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Animation IDs must be unique")
    }
}
