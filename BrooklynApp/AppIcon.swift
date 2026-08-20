import AppKit

/// The icons Brooklyn.app can wear. The raw value is the asset catalog name.
///
/// `brooklyn` is the icon compiled into the bundle, so selecting it means
/// dropping the custom icon rather than writing another one.
enum AppIcon: String, CaseIterable, Identifiable {
    case brooklyn = "AppIcon"
    case classic = "AppIconClassic"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .brooklyn: "Brooklyn"
        case .classic: "Classic"
        }
    }

    /// The image to write onto the bundle, or nil to restore the bundle's own
    /// icon. Alternate icons reach NSImage through
    /// ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS in project.yaml.
    var customImage: NSImage? {
        self == .brooklyn ? nil : NSImage(named: rawValue)
    }
}
