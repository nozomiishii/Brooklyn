import Observation
import XCTest

/// Tests for ConfigureSheetViewModel.
/// Regression: Customize toggle must reset selection to all when turned OFF.
/// Without this, stale saved preferences caused a black screen.
@MainActor
final class ConfigureSheetViewModelTests: XCTestCase {
    private var manager: BrooklynManager!
    private var viewModel: ConfigureSheetViewModel!

    override func setUp() {
        super.setUp()
        let bundle = Bundle(for: type(of: self))
        manager = BrooklynManager(bundle: bundle)
        manager.selectAll()
        manager.database.customize = false
        viewModel = ConfigureSheetViewModel(manager: manager)
    }

    func testCustomizeOffResetsToAllAnimations() {
        // Simulate: user had customize ON with partial selection
        viewModel.customize = true
        manager.database.selectedAnimations = [.appleBits]

        // User turns customize OFF
        viewModel.customize = false

        // Selection must be reset to all
        XCTAssertEqual(
            manager.selectedAnimations.count,
            Animation.allCases.count,
            "Turning customize OFF must reset selection to all animations",
        )
    }

    func testSelectAllSelectsAllAnimations() {
        manager.database.selectedAnimations = [.original]
        viewModel.selectAll()
        XCTAssertEqual(manager.selectedAnimations.count, Animation.allCases.count)
    }

    func testRemoveAllKeepsAtLeastOne() {
        viewModel.selectAll()
        viewModel.removeAll()
        XCTAssertGreaterThanOrEqual(manager.selectedAnimations.count, 1)
    }

    func testToggleUpdatesSelection() {
        manager.database.selectedAnimations = [.original]
        viewModel.toggle(.appleBits)
        XCTAssertTrue(manager.isSelected(.appleBits))
    }

    func testDefaultCustomizeIsFalse() {
        XCTAssertFalse(viewModel.customize)
    }

    func test個別選択の変更を画面に通知する() {
        assertSelectionChange { viewModel.toggle(.appleBits) }
        XCTAssertFalse(viewModel.isSelected(.appleBits))
        XCTAssertFalse(manager.isSelected(.appleBits))
    }

    func test全選択の変更を画面に通知する() {
        viewModel.removeAll()
        assertSelectionChange { viewModel.selectAll() }
        XCTAssertTrue(Animation.allCases.allSatisfy(viewModel.isSelected))
    }

    func test全解除の変更を画面に通知する() {
        assertSelectionChange { viewModel.removeAll() }
        XCTAssertTrue(viewModel.isSelected(.appleBits))
        XCTAssertFalse(viewModel.isSelected(.ballPit))
        XCTAssertEqual(manager.selectedAnimations, [.appleBits])
    }

    func testカスタマイズ解除で選択状態も画面に通知する() {
        viewModel.customize = true
        viewModel.removeAll()
        assertSelectionChange { viewModel.customize = false }
        XCTAssertTrue(Animation.allCases.allSatisfy(viewModel.isSelected))
        XCTAssertFalse(manager.database.customize)
    }

    private func assertSelectionChange(_ change: () -> Void) {
        let changed = expectation(description: "選択状態の変更が通知される")
        withObservationTracking {
            _ = Animation.allCases.map(viewModel.isSelected)
        } onChange: {
            changed.fulfill()
        }
        change()
        wait(for: [changed], timeout: 0.1)
    }
}
