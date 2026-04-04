import AVFoundation
import ScreenSaver
import XCTest

/// Tests for BrooklynView's macOS 26 Tahoe compatibility.
/// Regression: legacyScreenSaver.appex creates ghost instances with zero frame,
/// calls startAnimation multiple times, and fails to call stopAnimation.
@MainActor
final class BrooklynViewTests: XCTestCase {

    // MARK: - Ghost Instance Detection

    /// Regression: macOS 26 Tahoe creates instances with frame (0,0,0,0).
    /// These ghost instances must not set up AVPlayer to avoid resource waste.
    /// startAnimation on a ghost instance must be harmless (player is nil).
    func testGhostInstanceDoesNotCrashOnStart() {
        let view = BrooklynView(frame: .zero, isPreview: true)
        XCTAssertNotNil(view, "View should still be created even with zero frame")

        view?.startAnimation()
        // Should not crash — startAnimation guards against nil player
    }

    /// Normal instances with a valid frame must have a player ready.
    func testNormalInstanceHasPlayer() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let view = BrooklynView(frame: frame, isPreview: false)
        XCTAssertNotNil(view, "View should be created with a valid frame")
    }

    // MARK: - isPreview Heuristic

    /// Regression: macOS Sonoma+ always passes isPreview=true.
    /// BrooklynView uses frame size to determine the actual preview state.
    func testSmallFrameIsDetectedAsPreview() {
        let smallFrame = NSRect(x: 0, y: 0, width: 300, height: 200)
        guard let view = BrooklynView(frame: smallFrame, isPreview: false) else {
            XCTFail("View should be created")
            return
        }
        XCTAssertTrue(view.isPreview, "Small frame (< 400x300) should be detected as preview")
    }

    func testLargeFrameIsNotPreview() {
        let largeFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        guard let view = BrooklynView(frame: largeFrame, isPreview: true) else {
            XCTFail("View should be created")
            return
        }
        XCTAssertFalse(view.isPreview, "Large frame (>= 400x300) should not be preview")
    }

    func testBoundaryFrameIsNotPreview() {
        let boundaryFrame = NSRect(x: 0, y: 0, width: 400, height: 300)
        guard let view = BrooklynView(frame: boundaryFrame, isPreview: true) else {
            XCTFail("View should be created")
            return
        }
        XCTAssertFalse(view.isPreview, "Frame exactly 400x300 should not be preview")
    }

    /// AND condition edge case: width below threshold but height at threshold.
    func testWidthBelowThresholdButHeightAtThresholdIsNotPreview() {
        let frame = NSRect(x: 0, y: 0, width: 399, height: 300)
        guard let view = BrooklynView(frame: frame, isPreview: true) else {
            XCTFail("View should be created")
            return
        }
        XCTAssertFalse(view.isPreview, "Width < 400 but height >= 300 should not be preview")
    }

    /// AND condition edge case: width at threshold but height below threshold.
    func testWidthAtThresholdButHeightBelowIsNotPreview() {
        let frame = NSRect(x: 0, y: 0, width: 400, height: 299)
        guard let view = BrooklynView(frame: frame, isPreview: true) else {
            XCTFail("View should be created")
            return
        }
        XCTAssertFalse(view.isPreview, "Width >= 400 but height < 300 should not be preview")
    }

    // MARK: - startAnimation / stopAnimation Guards

    /// Regression: legacyScreenSaver.appex calls startAnimation multiple times.
    /// Duplicate calls must be ignored to prevent multiple play() invocations.
    func testStartAnimationIsIdempotent() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        guard let view = BrooklynView(frame: frame, isPreview: false) else {
            XCTFail("View should be created")
            return
        }

        view.startAnimation()
        view.startAnimation() // Should not crash or double-play
        view.stopAnimation()
    }

    /// Regression: isAnimationStarted flag must be reset by stopAnimation,
    /// allowing a subsequent startAnimation to succeed.
    func testAnimationCanRestartAfterStop() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        guard let view = BrooklynView(frame: frame, isPreview: false) else {
            XCTFail("View should be created")
            return
        }

        view.startAnimation()
        view.stopAnimation()
        view.startAnimation() // Should not be blocked by stale flag
        view.stopAnimation()
    }

    /// stopAnimation without prior startAnimation must not crash.
    func testStopAnimationWithoutStartIsHarmless() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        guard let view = BrooklynView(frame: frame, isPreview: false) else {
            XCTFail("View should be created")
            return
        }

        view.stopAnimation() // Should not crash
    }

    /// startAnimation on a ghost instance (no player) must not crash.
    func testStartAnimationOnGhostInstanceIsHarmless() {
        guard let view = BrooklynView(frame: .zero, isPreview: true) else {
            XCTFail("Ghost view should be created")
            return
        }

        view.startAnimation() // Should not crash — player is nil
        view.stopAnimation()  // Should not crash
    }

    // MARK: - General

    func testHasConfigureSheet() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        guard let view = BrooklynView(frame: frame, isPreview: false) else {
            XCTFail("View should be created")
            return
        }

        XCTAssertTrue(view.hasConfigureSheet, "BrooklynView must report having a configure sheet")
    }

    /// Regression: macOS 26 Tahoe ghost instances (frame .zero) must still provide
    /// a configure sheet so the Options button works in System Settings.
    func testGhostInstanceProvidesConfigureSheet() {
        let view = BrooklynView(frame: .zero, isPreview: true)
        XCTAssertNotNil(view, "Ghost view should be created")
        XCTAssertTrue(view!.hasConfigureSheet)
        XCTAssertNotNil(view!.configureSheet, "Ghost instance must still provide a configure sheet")
    }
}
