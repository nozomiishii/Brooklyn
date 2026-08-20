import AppKit
import Observation

/// Switches the icon of Brooklyn.app itself.
///
/// macOS has no setAlternateIconName equivalent, so the selection is written
/// onto the app bundle as a custom Finder icon. That outlives the process,
/// which is what this app needs: it quits as soon as its window closes.
@MainActor
@Observable
final class AppIconController {
    static let shared = AppIconController()

    private(set) var selected: AppIcon
    private(set) var lastError: String?

    private static let selectedKey = "selectedAppIcon"

    /// Not Database: that one wraps ScreenSaverDefaults, which resolves to the
    /// extension's sandbox container and is unreachable from the host app.
    private let defaults = UserDefaults.standard

    init() {
        selected = defaults.string(forKey: Self.selectedKey)
            .flatMap(AppIcon.init(rawValue:)) ?? .brooklyn
    }

    func select(_ icon: AppIcon) {
        selected = icon
        defaults.set(icon.rawValue, forKey: Self.selectedKey)
        apply(icon)
    }

    /// A cask upgrade swaps the whole bundle and takes the custom icon with
    /// it, so the selection is re-applied on every launch.
    func restoreOnLaunch() {
        guard selected != .brooklyn else { return }
        apply(selected)
    }

    /// A custom icon leaves Icon\r and a com.apple.FinderInfo xattr on the
    /// bundle, which `codesign --verify --strict` rejects (measured on macOS
    /// 26). Plain `--verify` passes, and selecting Brooklyn removes both.
    private func apply(_ icon: AppIcon) {
        lastError = nil

        let image = icon.customImage
        if icon != .brooklyn, image == nil {
            lastError = "The \(icon.displayName) icon is missing from the app bundle."
            return
        }

        let path = Bundle.main.bundlePath
        if !NSWorkspace.shared.setIcon(image, forFile: path, options: []) {
            lastError = "Could not write the icon to \(path)."
        }
    }
}
