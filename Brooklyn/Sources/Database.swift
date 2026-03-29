import ScreenSaver

/// Persists user preferences using ScreenSaverDefaults.
@MainActor
final class Database {
    private static let selectedAnimationsKey = "selectedAnimations"
    private static let numberOfLoopsKey = "numberOfLoops"
    private static let randomOrderKey = "randomOrder"

    private let defaults: ScreenSaverDefaults?

    init(moduleBundle: Bundle) {
        let identifier = moduleBundle.bundleIdentifier ?? "com.nozomiishii.brooklyn"
        self.defaults = ScreenSaverDefaults(forModuleWithName: identifier)
        registerDefaults()
    }

    private func registerDefaults() {
        defaults?.register(defaults: [
            Self.selectedAnimationsKey: [Animation.original.rawValue],
            Self.numberOfLoopsKey: 0,
            Self.randomOrderKey: false,
        ])
    }

    var selectedAnimations: [Animation] {
        get {
            guard let rawValues = defaults?.stringArray(forKey: Self.selectedAnimationsKey) else {
                return [.original]
            }
            let animations = rawValues.compactMap { Animation(rawValue: $0) }
            return animations.isEmpty ? [.original] : animations
        }
        set {
            let rawValues = newValue.map(\.rawValue)
            defaults?.set(rawValues, forKey: Self.selectedAnimationsKey)
            defaults?.synchronize()
        }
    }

    var numberOfLoops: Int {
        get { defaults?.integer(forKey: Self.numberOfLoopsKey) ?? 0 }
        set {
            defaults?.set(newValue, forKey: Self.numberOfLoopsKey)
            defaults?.synchronize()
        }
    }

    var randomOrder: Bool {
        get { defaults?.bool(forKey: Self.randomOrderKey) ?? false }
        set {
            defaults?.set(newValue, forKey: Self.randomOrderKey)
            defaults?.synchronize()
        }
    }
}
