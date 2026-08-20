.PHONY: generate build test format format-check lint clean install uninstall reset

SWIFT_SOURCES = Shared BrooklynApp BrooklynExtension BrooklynTests Canvas
EXTENSION_ID = dev.nozomiishii.brooklyn.extension

# Generate Xcode project from project.yaml
generate:
	xcodegen generate --spec project.yaml

# Build the app with the embedded screen saver extension
build: generate
	xcodebuild \
		-project Brooklyn.xcodeproj \
		-scheme Brooklyn \
		-configuration Release \
		-derivedDataPath build

# Run tests
test: generate
	xcodebuild test \
		-project Brooklyn.xcodeproj \
		-scheme BrooklynTests \
		-destination 'platform=macOS' \
		-derivedDataPath build

# Format Swift code (in-place)
format:
	mint run swiftformat $(SWIFT_SOURCES)

# Check formatting without modifying files (for CI)
format-check:
	mint run swiftformat $(SWIFT_SOURCES) --lint

# Lint Swift code
lint:
	mint run swiftlint --strict --config .swiftlint.yaml --cache-path .swiftlint-cache $(SWIFT_SOURCES)

# Install the app and register the screen saver extension.
# The build step registers the DerivedData copy with LaunchServices; drop it
# first so the /Applications registration wins.
install: build
	rm -rf /Applications/Brooklyn.app
	ditto build/Build/Products/Release/Brooklyn.app /Applications/Brooklyn.app
	-pluginkit -r build/Build/Products/Release/Brooklyn.app/Contents/PlugIns/BrooklynExtension.appex 2>/dev/null
	pluginkit -a /Applications/Brooklyn.app/Contents/PlugIns/BrooklynExtension.appex
	pluginkit -e use -i $(EXTENSION_ID)
	-killall WallpaperAgent 2>/dev/null

# Uninstall the app and unregister the extension
uninstall:
	-pluginkit -r /Applications/Brooklyn.app/Contents/PlugIns/BrooklynExtension.appex 2>/dev/null
	rm -rf /Applications/Brooklyn.app

# Reset caches and processes before testing.
# WallpaperAgent caches resolved extension paths; a stale entry (e.g. a
# DerivedData copy) makes System Settings silently refuse the selection.
# The picker tile is a PNG extracted once into the legacy provider's cache
# and never invalidated by replacing the appex, so it is flushed here too.
USER_CACHE = $(shell getconf DARWIN_USER_CACHE_DIR)
reset:
	-killall WallpaperAgent 2>/dev/null
	-killall "System Settings" 2>/dev/null
	rm -f ~/Library/Containers/$(EXTENSION_ID)/Data/Library/Preferences/ByHost/$(EXTENSION_ID).*.plist
	rm -rf "$(USER_CACHE)com.apple.wallpaper.extension.legacy/com.apple.wallpaper.legacy.thumbnails"
	rm -f "$(USER_CACHE)com.apple.wallpaper.agent/com.apple.wallpaper.view-model-cache/extension-com.apple.wallpaper.extension.legacy-screenSaver"

# Clean build artifacts
clean:
	rm -rf build Brooklyn.xcodeproj .swiftlint-cache
