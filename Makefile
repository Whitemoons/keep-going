APP_NAME := Keep Going
BUNDLE_ID := com.whitemoon.keepgoing
HELPER_ID := $(BUNDLE_ID).helper
# Any identity `codesign -s` accepts. Use "Developer ID Application: ..." for distribution.
SIGN_ID ?= Apple Development
# Keychain profile created with `xcrun notarytool store-credentials`.
NOTARY_PROFILE ?= keep-going

ARCHS := --arch arm64 --arch x86_64
BIN = $(shell swift build -c release $(ARCHS) --show-bin-path)
APP := build/$(APP_NAME).app
DMG := dist/KeepGoing.dmg

.PHONY: build app assets dmg notarize lint format clean

build:
	swift build -c release $(ARCHS)

app: build
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Library/LaunchDaemons" \
		"$(APP)/Contents/Resources"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(APP)/Contents/Resources/"
	cp Resources/$(HELPER_ID).plist "$(APP)/Contents/Library/LaunchDaemons/"
	cp "$(BIN)/KeepGoing" "$(BIN)/KeepGoingHelper" "$(APP)/Contents/MacOS/"
	codesign --force --options runtime --sign "$(SIGN_ID)" \
		--identifier $(HELPER_ID) "$(APP)/Contents/MacOS/KeepGoingHelper"
	codesign --force --options runtime --sign "$(SIGN_ID)" "$(APP)"
	codesign --verify --strict --deep "$(APP)"

# Regenerates the committed artwork. Only needed after changing the icon shapes or
# Scripts/make-assets; a normal build uses the files already in Resources/.
assets:
	rm -rf build/assets && mkdir -p build/assets
	swiftc -O Sources/KeepGoing/CanIcon.swift Scripts/make-assets/main.swift \
		-o build/assets/make-assets
	build/assets/make-assets build/assets
	iconutil --convert icns build/assets/AppIcon.iconset --output Resources/AppIcon.icns

dmg: app
	rm -rf build/dmg "$(DMG)"
	mkdir -p build/dmg dist
	cp -R "$(APP)" build/dmg/
	ln -s /Applications build/dmg/Applications
	hdiutil create -volname "$(APP_NAME)" -srcfolder build/dmg -ov -format UDZO "$(DMG)"
	codesign --force --sign "$(SIGN_ID)" "$(DMG)"

# Needs SIGN_ID set to a Developer ID Application identity.
notarize: dmg
	xcrun notarytool submit "$(DMG)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(DMG)"

lint:
	swift format lint --strict --recursive Sources Package.swift

format:
	swift format --in-place --recursive Sources Package.swift

clean:
	rm -rf .build build dist
