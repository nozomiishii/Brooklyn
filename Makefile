.PHONY: generate build test format format-check lint clean install uninstall reset

SWIFT_SOURCES = Brooklyn BrooklynTests Canvas

# Generate Xcode project from project.yaml
generate:
	xcodegen generate --spec project.yaml

# Build the screen saver
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

# Install the screen saver
install: build
	cp -R build/Build/Products/Release/Brooklyn.saver ~/Library/Screen\ Savers/
	codesign --force --sign - ~/Library/Screen\ Savers/Brooklyn.saver
	-killall legacyScreenSaver 2>/dev/null

# Uninstall the screen saver
uninstall:
	rm -rf ~/Library/Screen\ Savers/Brooklyn.saver

# Reset screen saver caches and processes before testing
reset:
	-killall legacyScreenSaver 2>/dev/null
	-killall WallpaperAgent 2>/dev/null
	-killall "System Settings" 2>/dev/null
	rm -rf ~/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Caches/*
	rm -f ~/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Preferences/ByHost/dev.nozomiishii.brooklyn.*.plist
	-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -r -domain local -domain user

# Clean build artifacts
clean:
	rm -rf build Brooklyn.xcodeproj .swiftlint-cache
