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
            "Turning customize OFF must reset selection to all animations"
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
}
