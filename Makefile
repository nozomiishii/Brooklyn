.PHONY: generate build test lint clean install uninstall reset

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

# Lint Swift code
lint:
	swiftlint --config .swiftlint.yaml

# Install the screen saver
install: build
	cp -R build/Build/Products/Release/Brooklyn.saver ~/Library/Screen\ Savers/
	codesign --force --sign - ~/Library/Screen\ Savers/Brooklyn.saver

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
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain user

# Clean build artifacts
clean:
	rm -rf build Brooklyn.xcodeproj
