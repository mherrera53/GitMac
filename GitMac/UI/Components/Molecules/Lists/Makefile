APP_NAME ?= GitMac
SCHEME ?= GitMac
CONFIGURATION ?= Release
BUNDLE_ID ?= com.example.GitMac
EXPORT_DIR ?= build/export
BUILD_DIR ?= build
DMG_NAME ?= $(APP_NAME).dmg

.PHONY: all build export sign notarize dmg package locate reveal install clean help

all: package

build:
	@echo "Building $(APP_NAME)..."
	xcodebuild archive -destination 'generic/platform=macOS' -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -archivePath "$(BUILD_DIR)/$(APP_NAME).xcarchive" clean archive

export: build
	@echo "Exporting $(APP_NAME)..."
	@printf '<?xml version="1.0" encoding="UTF-8"?>\n\
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n\
<plist version="1.0">\n\
<dict>\n\
\t<key>method</key>\n\
\t<string>developer-id</string>\n\
\t<key>signingStyle</key>\n\
\t<string>manual</string>\n\
\t<key>signingCertificate</key>\n\
\t<string>Developer ID Application</string>\n\
\t<key>provisioningProfiles</key>\n\
\t<dict>\n\
\t\t<key>$(BUNDLE_ID)</key>\n\
\t\t<string></string>\n\
\t</dict>\n\
</dict>\n\
</plist>\n' > ExportOptions.plist
	@mkdir -p "$(EXPORT_DIR)"
	xcodebuild -exportArchive -archivePath "$(BUILD_DIR)/$(APP_NAME).xcarchive" -exportPath "$(EXPORT_DIR)" -exportOptionsPlist ExportOptions.plist

sign: export
ifndef DEVELOPER_ID
	@echo "Error: DEVELOPER_ID environment variable not set." >&2
	@exit 1
endif
	@echo "Signing $(APP_NAME)..."
	codesign --deep --force --options runtime --timestamp -s "$(DEVELOPER_ID)" "$(EXPORT_DIR)/$(APP_NAME).app"

notarize: sign
ifndef APPLE_ID
	@echo "Error: APPLE_ID environment variable not set." >&2
	@exit 1
endif
ifndef APPLE_TEAM_ID
	@echo "Error: APPLE_TEAM_ID environment variable not set." >&2
	@exit 1
endif
	@echo "Notarizing $(APP_NAME)..."
	xcrun notarytool submit "$(EXPORT_DIR)/$(APP_NAME).app" --apple-id "$(APPLE_ID)" --team-id "$(APPLE_TEAM_ID)" --keychain-profile AC_PASSWORD --wait
	xcrun stapler staple "$(EXPORT_DIR)/$(APP_NAME).app"

dmg: notarize
	@echo "Creating DMG for $(APP_NAME)..."
	@rm -rf "$(EXPORT_DIR)/dmg"
	@mkdir -p "$(EXPORT_DIR)/dmg"
	@cp -R "$(EXPORT_DIR)/$(APP_NAME).app" "$(EXPORT_DIR)/dmg/"
	@ln -s /Applications "$(EXPORT_DIR)/dmg/Applications"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(EXPORT_DIR)/dmg" -ov -format UDZO "$(EXPORT_DIR)/$(DMG_NAME)"

package: dmg
	@echo "Package created at: $(EXPORT_DIR)/$(DMG_NAME)"

locate:
	@echo "Expected DMG path: $(EXPORT_DIR)/$(DMG_NAME)"
	@if [ -f "$(EXPORT_DIR)/$(DMG_NAME)" ]; then \
		echo "Found: $(EXPORT_DIR)/$(DMG_NAME)"; \
	else \
		echo "DMG not found in $(EXPORT_DIR). Searching project tree..."; \
		find . -type f -name "$(DMG_NAME)" -print || true; \
	fi

reveal:
	@if [ -f "$(EXPORT_DIR)/$(DMG_NAME)" ]; then \
		echo "Revealing in Finder..."; \
		open -R "$(EXPORT_DIR)/$(DMG_NAME)"; \
	else \
		echo "DMG not found in $(EXPORT_DIR). Opening export directory..."; \
		open "$(EXPORT_DIR)" || true; \
	fi

install: notarize
	@echo "Installing $(APP_NAME) to /Applications..."
	@if [ -d "/Applications/$(APP_NAME).app" ]; then \
		echo "Existing app found at /Applications/$(APP_NAME).app"; \
		printf "Replace it? [y/N] "; \
		read ans; \
		case $$ans in \
			y|Y) echo "Replacing existing app..."; rm -rf "/Applications/$(APP_NAME).app" ;; \
			*) echo "Install cancelled."; exit 1 ;; \
		esac; \
	fi
	@ditto "$(EXPORT_DIR)/$(APP_NAME).app" "/Applications/$(APP_NAME).app"
	@echo "Installed at /Applications/$(APP_NAME).app"

clean:
	@echo "Cleaning build and export directories..."
	@rm -rf "$(BUILD_DIR)" "$(EXPORT_DIR)" ExportOptions.plist

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build       - Build the archive using xcodebuild"
	@echo "  export      - Export the archive to app bundle"
	@echo "  sign        - Sign the exported app (requires DEVELOPER_ID env)"
	@echo "  notarize    - Notarize the signed app (requires APPLE_ID and APPLE_TEAM_ID env)"
	@echo "  dmg         - Create a DMG containing the notarized app"
	@echo "  package     - Complete process and show final DMG path"
	@echo "  locate      - Print the expected DMG path and search for it if missing"
	@echo "  reveal      - Reveal the DMG in Finder (or open export dir if missing)"
	@echo "  install     - Copy the notarized app to /Applications (prompts to replace if exists)"
	@echo "  clean       - Remove build and export directories"
	@echo "  help        - Show this help message"
	@echo ""
	@echo "Variables (can be overridden):"
	@echo "  APP_NAME         (default: $(APP_NAME))"
	@echo "  SCHEME           (default: $(SCHEME))"
	@echo "  CONFIGURATION    (default: $(CONFIGURATION))"
	@echo "  BUNDLE_ID        (default: $(BUNDLE_ID))"
	@echo "  EXPORT_DIR       (default: $(EXPORT_DIR))"
	@echo "  BUILD_DIR        (default: $(BUILD_DIR))"
	@echo "  DMG_NAME         (default: $(DMG_NAME))"
