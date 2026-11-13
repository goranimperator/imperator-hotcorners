APP_NAME     = Imperator HotCorners
BINARY_NAME  = ImperatorHotCorners
BUNDLE       = build/$(APP_NAME).app
DIST         = dist
ZIP          = $(DIST)/Imperator-HotCorners-$(VERSION).zip
BUILD_NUMBER = $(shell git rev-list --count HEAD 2>/dev/null || echo 1)
# `release` commits before it tags, but every variable expands first, so the
# tagged build needs the count plus that commit.
RELEASE_BUILD_NUMBER = $(shell n=$$(git rev-list --count HEAD 2>/dev/null) && echo $$((n + 1)) || echo 1)
ARCHS        = --arch arm64 --arch x86_64
ICONSET      = build/AppIcon.iconset
# Self-signed, not ad-hoc: the login item registration is keyed to the
# designated requirement, and an ad-hoc cdhash changes on every build.
CODESIGN_IDENTITY ?= Imperator Dev

NOTES ?= The app now checks GitHub once a day for a newer release and shows it in the \
panel, with one notification per version. Updating is still by hand. Turn the check off \
with Check for updates in the footer.
GATEKEEPER = Signed with a self-signed certificate and not notarized, so \
Gatekeeper blocks the first launch: right-click the app and choose Open, or run \
\`xattr -dr com.apple.quarantine \"/Applications/$(APP_NAME).app\"\`.

.PHONY: all build test icon install run clean check-version dist release

all: build

build:
	swift build -c release $(ARCHS)
	@rm -rf "$(BUNDLE)"
	@mkdir -p "$(BUNDLE)/Contents/MacOS" "$(BUNDLE)/Contents/Resources"
	cp "$$(swift build -c release $(ARCHS) --show-bin-path)/$(BINARY_NAME)" "$(BUNDLE)/Contents/MacOS/$(BINARY_NAME)"
	cp Resources/Info.plist "$(BUNDLE)/Contents/Info.plist"
	@if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$(BUNDLE)/Contents/Resources/AppIcon.icns"; \
		else echo "warning: Resources/AppIcon.icns is missing, the bundle shows the generic icon (gate M6)"; fi
	codesign --force --sign "$(CODESIGN_IDENTITY)" "$(BUNDLE)"
	@echo "Built: $(BUNDLE)"

test:
	swift test

# Resources/AppIcon.icns is the source. The README shows the 256 px slice of it at
# width 128, which renders at 256 physical pixels on a Retina Mac.
icon:
	@test -f Resources/AppIcon.icns || { echo "Resources/AppIcon.icns is missing"; exit 1; }
	@rm -rf "$(ICONSET)"
	iconutil -c iconset Resources/AppIcon.icns -o "$(ICONSET)"
	cp "$(ICONSET)/icon_256x256.png" Resources/AppIcon.png

install: build
	@pkill -x $(BINARY_NAME) 2>/dev/null || true
	@sleep 0.5
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(BUNDLE)" "/Applications/$(APP_NAME).app"
	open "/Applications/$(APP_NAME).app"

run: build
	open "$(BUNDLE)"

clean:
	rm -rf build dist

check-version:
	@test -n "$(VERSION)" || { echo "Usage: make $(MAKECMDGOALS) VERSION=1.0.0"; exit 1; }

# Build a distributable zip. Touches nothing in git, nothing on the remote.
dist: check-version build
	@mkdir -p $(DIST)
	rm -f "$(ZIP)"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" "$(BUNDLE)/Contents/Info.plist"
	codesign --force --sign "$(CODESIGN_IDENTITY)" "$(BUNDLE)"
	ditto -c -k --sequesterRsrc --keepParent "$(BUNDLE)" "$(ZIP)"
	@echo "Packaged: $(ZIP)"

# Bump version, commit, tag, push, publish the GitHub release with the zip attached.
release: check-version
	@git rev-parse --verify -q HEAD >/dev/null || { echo "No commits yet: commit the source first."; exit 1; }
	@test -z "$$(git status --porcelain)" || { echo "Working tree not clean (untracked files count): commit first."; exit 1; }
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" Resources/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(RELEASE_BUILD_NUMBER)" Resources/Info.plist
	$(MAKE) dist VERSION=$(VERSION) BUILD_NUMBER=$(RELEASE_BUILD_NUMBER)
	git add Resources/Info.plist
	git commit -m "Release v$(VERSION)"
	git tag -a v$(VERSION) -m "$(APP_NAME) $(VERSION)"
	git push origin HEAD
	git push origin v$(VERSION)
	gh release create v$(VERSION) \
		--title "$(APP_NAME) $(VERSION)" \
		--notes "$(NOTES) $(GATEKEEPER)" \
		"$(ZIP)#$(APP_NAME) $(VERSION) (macOS)"
	@echo "Released v$(VERSION)"
