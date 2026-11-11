import Observation

/// ViewModel bridging BrooklynManager's state to the SwiftUI ConfigureSheet.
@MainActor
@Observable
final class ConfigureSheetViewModel {
    private let manager: BrooklynManager
    private(set) var selectedAnimations: [Animation]

    var customize: Bool {
        didSet {
            manager.database.customize = customize
            if !customize {
                manager.selectAll()
                selectedAnimations = manager.selectedAnimations
            }
        }
    }

    var numberOfLoops: Int {
        didSet { manager.database.numberOfLoops = numberOfLoops }
    }

    var randomOrder: Bool {
        didSet { manager.database.randomOrder = randomOrder }
    }

    init(manager: BrooklynManager) {
        self.manager = manager
        selectedAnimations = manager.selectedAnimations
        customize = manager.database.customize
        numberOfLoops = manager.database.numberOfLoops
        randomOrder = manager.database.randomOrder
    }

    func isSelected(_ animation: Animation) -> Bool {
        selectedAnimations.contains(animation)
    }

    func toggle(_ animation: Animation) {
        manager.toggle(animation)
        selectedAnimations = manager.selectedAnimations
    }

    func selectAll() {
        manager.selectAll()
        selectedAnimations = manager.selectedAnimations
    }

    func removeAll() {
        manager.removeAll()
        selectedAnimations = manager.selectedAnimations
    }
}
