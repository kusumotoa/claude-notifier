# claude-notifier Makefile
# Builds a macOS .app bundle from Swift Package

PRODUCT_NAME = claude-notifier
APP_NAME = $(PRODUCT_NAME).app
BUILD_DIR = .build/release
APP_DIR = $(APP_NAME)/Contents
BINARY = $(BUILD_DIR)/$(PRODUCT_NAME)

# Code signing
SIGNING_IDENTITY = Developer ID Application: Masahiro Kusumoto (N64RMB3HK7)
KEYCHAIN_PROFILE = claude-notifier-notarize

.PHONY: all build bundle clean install uninstall release notarize help

all: bundle

# Build the Swift package in release mode
build:
	swift build -c release

# Create the .app bundle structure (ad-hoc signed for local use)
bundle: build
	@echo "Creating app bundle..."
	rm -rf $(APP_NAME)
	mkdir -p $(APP_DIR)/MacOS
	mkdir -p $(APP_DIR)/Resources
	cp $(BINARY) $(APP_DIR)/MacOS/$(PRODUCT_NAME)
	cp Resources/Info.plist $(APP_DIR)/Info.plist
	@echo "Signing app bundle (ad-hoc)..."
	codesign --force --deep --sign - $(APP_NAME)
	@echo "App bundle created: $(APP_NAME)"

# Create release with Developer ID signing and notarization
release: build
	@echo "Creating app bundle..."
	rm -rf $(APP_NAME)
	mkdir -p $(APP_DIR)/MacOS
	mkdir -p $(APP_DIR)/Resources
	cp $(BINARY) $(APP_DIR)/MacOS/$(PRODUCT_NAME)
	cp Resources/Info.plist $(APP_DIR)/Info.plist
	@echo "Signing with Developer ID..."
	codesign --force --options runtime --sign "$(SIGNING_IDENTITY)" $(APP_NAME)
	@echo "Creating zip for notarization..."
	rm -f $(PRODUCT_NAME).zip
	ditto -c -k --keepParent $(APP_NAME) $(PRODUCT_NAME).zip
	@echo "Submitting for notarization..."
	xcrun notarytool submit $(PRODUCT_NAME).zip --keychain-profile "$(KEYCHAIN_PROFILE)" --wait
	@echo "Stapling notarization ticket..."
	xcrun stapler staple $(APP_NAME)
	@echo "Recreating zip with stapled app..."
	rm -f $(PRODUCT_NAME).zip
	ditto -c -k --keepParent $(APP_NAME) $(PRODUCT_NAME).zip
	@echo "Release created: $(PRODUCT_NAME).zip"

# Clean build artifacts
clean:
	swift package clean
	rm -rf $(APP_NAME)
	rm -rf .build
	rm -f $(PRODUCT_NAME).zip

# Install to /Applications
install: bundle
	@echo "Installing to /Applications..."
	rm -rf /Applications/$(APP_NAME)
	cp -R $(APP_NAME) /Applications/
	@echo "Creating symlink in /usr/local/bin..."
	mkdir -p /usr/local/bin
	ln -sf /Applications/$(APP_NAME)/Contents/MacOS/$(PRODUCT_NAME) /usr/local/bin/$(PRODUCT_NAME)
	@echo "Installed successfully!"
	@echo "You can now use: $(PRODUCT_NAME) -message 'Hello'"

# Uninstall
uninstall:
	@echo "Uninstalling..."
	rm -rf /Applications/$(APP_NAME)
	rm -f /usr/local/bin/$(PRODUCT_NAME)
	@echo "Uninstalled successfully!"

# Show help
help:
	@echo "claude-notifier build targets:"
	@echo ""
	@echo "  make build    - Build the Swift package"
	@echo "  make bundle   - Create .app bundle (ad-hoc signed, local use)"
	@echo "  make release  - Create signed & notarized release"
	@echo "  make install  - Install to /Applications and /usr/local/bin"
	@echo "  make uninstall- Remove from /Applications and /usr/local/bin"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make help     - Show this help"
