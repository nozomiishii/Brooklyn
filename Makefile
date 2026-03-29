.PHONY: generate build test lint clean install uninstall

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

# Clean build artifacts
clean:
	rm -rf build Brooklyn.xcodeproj
