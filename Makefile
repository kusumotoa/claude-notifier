# claude-notifier Makefile
# Builds a macOS .app bundle from Swift Package

PRODUCT_NAME = claude-notifier
APP_NAME = $(PRODUCT_NAME).app
BUILD_DIR = .build/release
APP_DIR = $(APP_NAME)/Contents
BINARY = $(BUILD_DIR)/$(PRODUCT_NAME)

.PHONY: all build bundle clean install uninstall release zip

all: bundle

# Build the Swift package in release mode
build:
	swift build -c release

# Create the .app bundle structure
bundle: build
	@echo "Creating app bundle..."
	rm -rf $(APP_NAME)
	mkdir -p $(APP_DIR)/MacOS
	mkdir -p $(APP_DIR)/Resources
	cp $(BINARY) $(APP_DIR)/MacOS/$(PRODUCT_NAME)
	cp Resources/Info.plist $(APP_DIR)/Info.plist
	@echo "Signing app bundle..."
	codesign --force --deep --sign - $(APP_NAME)
	@echo "App bundle created: $(APP_NAME)"

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

# Create release zip for distribution
release: bundle
	@echo "Creating release archive..."
	rm -f $(PRODUCT_NAME).zip
	zip -r $(PRODUCT_NAME).zip $(APP_NAME)
	@echo "Release archive created: $(PRODUCT_NAME).zip"

# Show help
help:
	@echo "claude-notifier build targets:"
	@echo ""
	@echo "  make build    - Build the Swift package"
	@echo "  make bundle   - Create the .app bundle (default)"
	@echo "  make install  - Install to /Applications and /usr/local/bin"
	@echo "  make uninstall- Remove from /Applications and /usr/local/bin"
	@echo "  make release  - Create a zip archive for distribution"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make help     - Show this help"
