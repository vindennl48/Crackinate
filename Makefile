APP_NAME     := Crackinate
BUILD_DIR    := .build
BUILD_ARCH   := arm64
RELEASE_DIR  := $(BUILD_DIR)/release
APP_BUNDLE   := $(RELEASE_DIR)/$(APP_NAME).app
CONTENTS     := $(APP_BUNDLE)/Contents
MACOS_DIR    := $(CONTENTS)/MacOS
RESOURCES    := $(CONTENTS)/Resources
SWIFT_FILES  := $(shell find Crackinate -name '*.swift' | sort)
PLIST_SRC    := Crackinate/Info.plist
ASSETS_DIR   := Crackinate/Assets.xcassets

.PHONY: all build release app clean run debug

all: app

# Debug build (fast, no optimization)
build:
	swift build -c debug --arch $(BUILD_ARCH)

# Release build (optimized)
release:
	swift build -c release --arch $(BUILD_ARCH)

# Create full .app bundle
app: release
	@echo "📦 Creating $(APP_NAME).app bundle..."
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES)
	@cp $(BUILD_DIR)/$(BUILD_ARCH)-apple-macosx/release/$(APP_NAME) $(MACOS_DIR)/
	@cp $(PLIST_SRC) $(CONTENTS)/Info.plist
	@cp -R $(ASSETS_DIR) $(RESOURCES)/Assets.xcassets 2>/dev/null || true
	@xattr -rd com.apple.quarantine $(APP_BUNDLE) 2>/dev/null || true
	@echo "✅ $(APP_BUNDLE) created"

# Run debug build
run: build
	$(BUILD_DIR)/$(BUILD_ARCH)-apple-macosx/debug/$(APP_NAME)

# Open release app
open: app
	open $(APP_BUNDLE)

# Clean
clean:
	rm -rf $(BUILD_DIR)

# Debug info
debug:
	@echo "Swift files: $(SWIFT_FILES)"
	@echo "Build arch:  $(BUILD_ARCH)"
	@echo "App bundle:  $(APP_BUNDLE)"
