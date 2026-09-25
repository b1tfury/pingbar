APP        := PingBar
VERSION    := 0.1.0
BUNDLE     := build/$(APP).app
CONTENTS   := $(BUNDLE)/Contents
BIN        := .build/release/$(APP)
DMG        := build/$(APP)-$(VERSION).dmg
# Command Line Tools ship swift-testing but the macro plugin isn't auto-discovered.
TEST_FLAGS := -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing

.PHONY: build app run dev test install package clean

build:
	swift build -c release

app: build
	rm -rf $(BUNDLE)
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp $(BIN) $(CONTENTS)/MacOS/$(APP)
	cp Resources/Info.plist $(CONTENTS)/Info.plist
	cp Resources/AppIcon.icns $(CONTENTS)/Resources/AppIcon.icns
	codesign --force --sign - $(BUNDLE)
	@echo "Built $(BUNDLE)"

# Drag-to-Applications disk image for GitHub releases.
package: app
	rm -rf build/dmg $(DMG)
	mkdir -p build/dmg
	cp -R $(BUNDLE) build/dmg/
	ln -s /Applications build/dmg/Applications
	hdiutil create -volname $(APP) -srcfolder build/dmg -ov -format UDZO $(DMG)
	rm -rf build/dmg
	@echo "Packaged $(DMG)"

run: app
	open $(BUNDLE)

dev:
	swift run

test:
	swift test $(TEST_FLAGS)

install: app
	rm -rf /Applications/$(APP).app
	cp -R $(BUNDLE) /Applications/
	@echo "Installed /Applications/$(APP).app"

clean:
	rm -rf .build build
