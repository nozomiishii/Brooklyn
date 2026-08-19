import Foundation
import os

private let logger = Logger(subsystem: "dev.nozomiishii.brooklyn.extension", category: "Extension")

/// Principal class of the screen saver app extension.
/// Referenced from Info.plist as NSExtensionPrincipalClass.
///
/// Kept minimal on purpose: Apple's own screen saver appexes (e.g. Arabesque)
/// only implement init() and let the framework drive the lifecycle. The
/// framework creates and discards several instances per process, so this
/// class must stay stateless.
@objc(BrooklynExtension)
final class BrooklynExtension: ScreenSaverExtension {
    @objc override init() {
        logger.info("init() PID=\(ProcessInfo.processInfo.processIdentifier, privacy: .public)")
        super.init()
    }
}
