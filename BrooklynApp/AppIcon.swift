import AppKit
import SwiftUI

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
        guard self != .brooklyn, let artwork = NSImage(named: rawValue) else { return nil }
        return Self.appShaped(artwork)
    }

    /// macOS masks asset catalog app icons into the rounded square shape, but
    /// draws a custom Finder icon exactly as handed over. Without the same
    /// shape the artwork sits square in Finder and reads as a picture rather
    /// than an app.
    ///
    /// Proportions measured against Calculator.app on macOS 26: a 256pt canvas
    /// carries a 204pt body, inset 26pt on every side.
    private static func appShaped(_ artwork: NSImage) -> NSImage {
        let canvas: CGFloat = 1024
        let inset = canvas * 0.1015
        let body = canvas - inset * 2
        let rect = NSRect(x: inset, y: inset, width: body, height: body)
        let shape = RoundedRectangle(cornerRadius: body * 0.2237, style: .continuous)
            .path(in: rect)
            .cgPath

        let image = NSImage(size: NSSize(width: canvas, height: canvas))
        image.lockFocus()
        defer { image.unlockFocus() }

        guard let context = NSGraphicsContext.current?.cgContext else { return artwork }

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -canvas * 0.012),
            blur: canvas * 0.024,
            color: NSColor.black.withAlphaComponent(0.28).cgColor
        )
        context.addPath(shape)
        context.setFillColor(NSColor.black.cgColor)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(shape)
        context.clip()
        artwork.draw(in: rect)
        context.restoreGState()

        return image
    }
}
