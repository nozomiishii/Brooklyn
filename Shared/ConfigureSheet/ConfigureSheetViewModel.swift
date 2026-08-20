import SwiftUI

/// ViewModel bridging BrooklynManager's state to the SwiftUI ConfigureSheet.
@MainActor
final class ConfigureSheetViewModel: ObservableObject {
    private let manager: BrooklynManager

    @Published var customize: Bool {
        didSet {
            manager.database.customize = customize
            if !customize {
                manager.selectAll()
            }
        }
    }

    @Published var numberOfLoops: Int {
        didSet { manager.database.numberOfLoops = numberOfLoops }
    }

    @Published var randomOrder: Bool {
        didSet { manager.database.randomOrder = randomOrder }
    }

    init(manager: BrooklynManager) {
        self.manager = manager
        customize = manager.database.customize
        numberOfLoops = manager.database.numberOfLoops
        randomOrder = manager.database.randomOrder
    }

    func isSelected(_ animation: Animation) -> Bool {
        manager.isSelected(animation)
    }

    func toggle(_ animation: Animation) {
        manager.toggle(animation)
        objectWillChange.send()
    }

    func selectAll() {
        manager.selectAll()
        objectWillChange.send()
    }

    func removeAll() {
        manager.removeAll()
        objectWillChange.send()
    }
}
