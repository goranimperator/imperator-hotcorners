# Gates: Imperator HotCorners v1

OWNS: Package.swift, Makefile, .gitignore, LICENSE, README.md, CLAUDE.md, SPEC.md, GATES.md, Resources/**, Sources/**, Tests/**, scripts/**

Scope: a signed, universal menu bar app that reads the four hot corners from the Dock, writes them the way System Settings does, and turns them all off and back on from a Disable HotCorners switch under the four pop-ups, built to the Imperator brandbook (SPEC.md).

Runnable gates run from the repo root with /bin/sh. Tools needed: Xcode 27 command line tools (swift, otool, lipo, codesign, plutil, strings), node, and the Imperator Dev signing identity in the login keychain. G5 to G8 run the built binary; G5 reads the live Dock and writes nothing.

- [x] G1: universal release bundle builds and is signed with Imperator Dev
  CHECK: make build >/dev/null 2>&1 && B="build/Imperator HotCorners.app" && lipo -archs "$B/Contents/MacOS/ImperatorHotCorners" | grep -q arm64 && lipo -archs "$B/Contents/MacOS/ImperatorHotCorners" | grep -q x86_64 && codesign --verify --strict "$B" && codesign -dvv "$B" 2>&1 | grep -q "Authority=Imperator Dev" && echo G1_BUILD_SIGN_OK
  EXPECT: G1_BUILD_SIGN_OK
  EVIDENCE: exit=0; shell=/bin/sh; cwd=<repo root>; path=58838ac404b6/37 entries; output=G1_BUILD_SIGN_OK

- [x] G2: every unit test passes
  CHECK: mkdir -p build && swift test > build/swift-test.log 2>&1 && echo G2_TESTS_OK || { tail -40 build/swift-test.log; exit 1; }
  EXPECT: G2_TESTS_OK
  EVIDENCE: exit=0; shell=/bin/sh; cwd=<repo root>; path=58838ac404b6/37 entries; output=G2_TESTS_OK

- [x] G3: binary stamped minos 26.0 and sdk 26.0 (brandbook Toolchain and SDK)
  CHECK: V=$(otool -arch arm64 -l "build/Imperator HotCorners.app/Contents/MacOS/ImperatorHotCorners" | grep -A5 LC_BUILD_VERSION) && echo "$V" | grep -q "minos 26.0" && echo "$V" | grep -q "sdk 26.0" && echo G3_STAMP_OK
  EXPECT: G3_STAMP_OK
  EVIDENCE: exit=0; shell=/bin/sh; cwd=<repo root>; path=58838ac404b6/37 entries; output=G3_STAMP_OK

- [x] G4: bundle identity, menu bar app type, minimum macOS and copyright
  CHECK: P="build/Imperator HotCorners.app/Contents/Info.plist" && test "$(plutil -extract CFBundleIdentifier raw "$P")" = com.goranimperator.ImperatorHotCorners && test "$(plutil -extract CFBundleName raw "$P")" = "Imperator HotCorners" && test "$(plutil -extract LSUIElement raw "$P")" = true && test "$(plutil -extract LSMinimumSystemVersion raw "$P")" = 26.0 && plutil -extract NSHumanReadableCopyright raw "$P" | grep -q "Goran Imperator. MIT License." && echo G4_PLIST_OK
  EXPECT: G4_PLIST_OK
  EVIDENCE: exit=0; shell=/bin/sh; cwd=<repo root>; path=58838ac404b6/37 entries; output=G4_PLIST_OK

- [x] G5: the app reads the same four corners the Dock preferences hold (read only)
  CHECK: "build/Imperator HotCorners.app/Contents/MacOS/ImperatorHotCorners" --dock-check
  EXPECT: DOCK_CHECK_OK
  EVIDENCE: exit=0; shell=/bin/sh; cwd=<repo root>; path=58838ac404b6/37 entries; output=BR - (1, mods 0) prefs 1/0 | DOCK_CHECK_OK

- [x] G6: menu bar glyph matches the geometry in SPEC.md: WidgetClock's frame, dots where the spec puts them, symmetric
  CHECK: "build/Imperator HotCorners.app/Contents/MacOS/ImperatorHotCorners" --icon-check
  EXPECT: ICON_CHECK_OK
  EVIDENCE: exit=0; shell=/bin/sh; cwd=<repo root>; path=58838ac404b6/37 entries; output=stroke 16pt frame 14.0 x 11.0 at (1.0, 3.0), spec 14.0 x 11.0 | ICON_CHECK_OK

- [x] G7: About panel fits brandbook section 10 and reads version and copyright from the bundle
  CHECK: "build/Imperator HotCorners.app/Contents/MacOS/ImperatorHotCorners" --about-check
  EXPECT: ABOUT_PANEL_OK
  EVIDENCE: exit=0; shell=/bin/sh; cwd=<repo root>; path=58838ac404b6/37 entries; output=copyright line: © 1986-2026 Goran Imperator | ABOUT_PANEL_OK

- [x] G8: every panel state renders and every plain action title fits its 178 pt column in the real control
  CHECK: "build/Imperator HotCorners.app/Contents/MacOS/ImperatorHotCorners" --render-preview build/preview
  EXPECT: PREVIEW_OK
  EVIDENCE: exit=0; shell=/bin/sh; cwd=<repo root>; path=58838ac404b6/37 entries; output=fit: every plain title fits 178.0 pt; 74 of 150 titles with modifier keys truncate | PREVIEW_OK

- [x] G9: no em dash or en dash in shipped text (scanner proves itself on a fixture first)
  CHECK: node scripts/check-dashes.mjs
  EXPECT: DASHES_OK
  EVIDENCE: exit=0; shell=/bin/sh; cwd=<repo root>; path=58838ac404b6/37 entries; output=scanned 38 files | DASHES_OK

- [x] G10: brand rules hold in source: no bare accentColor, no NSPopover, no pointing hand on a switch, accent override set
  CHECK: node scripts/check-brand.mjs
  EXPECT: BRAND_OK
  EVIDENCE: exit=0; shell=/bin/sh; cwd=<repo root>; path=58838ac404b6/37 entries; output=BRAND_OK

- [x] G11: the DEBUG fake Dock is in debug builds and absent from the release binary
  CHECK: swift build >/dev/null 2>&1 && strings -a .build/debug/ImperatorHotCorners | grep -q IMPERATOR_HOTCORNERS_FAKE && ! strings -a "build/Imperator HotCorners.app/Contents/MacOS/ImperatorHotCorners" | grep -q IMPERATOR_HOTCORNERS_FAKE && echo G11_NO_DEBUG_OK
  EXPECT: G11_NO_DEBUG_OK
  EVIDENCE: exit=0; shell=/bin/sh; cwd=<repo root>; path=58838ac404b6/37 entries; output=G11_NO_DEBUG_OK

- [x] G13: the panel opens at the pop-up menu level, a click on the switch lands and turns the corners off and on, a click inside keeps it open, Escape closes it, it reopens, it grows for a notice, and nothing closes it on the click itself: neither a click in the menu bar nor the app losing activation takes it down under the pointer, so the second click after a pause still closes it
  CHECK: "build/Imperator HotCorners.app/Contents/MacOS/ImperatorHotCorners" --panel-check
  EXPECT: PANEL_CHECK_OK
  EVIDENCE: exit=0; shell=/bin/sh; cwd=<repo root>; path=58838ac404b6/37 entries; output=PANEL_CHECK_OK

- [x] G12: the bundle carries the real app icon
  CHECK: test -f Resources/AppIcon.png && test -f "build/Imperator HotCorners.app/Contents/Resources/AppIcon.icns" && echo G12_ICON_OK
  EXPECT: G12_ICON_OK
  EVIDENCE: exit=0; shell=/bin/sh; cwd=<repo root>; path=58838ac404b6/37 entries; output=G12_ICON_OK

- [x] M1: Goran ran `swift scripts/calibrate-dock.swift --run`; the output shows ORDER, CORNER_CODES, STATE_RESTORED and CALIBRATION_OK, and those codes are pinned in CoreDockBackend and its test (build plan Task 3)
  EVIDENCE: Goran's run 2026-10-31: ORDER action,corner,modifiers; CORNER_CODES tl=0 tr=1 bl=2 br=3; STATE_RESTORED; CALIBRATION_OK. Codes pinned in CoreDockBackend.cornerCode and test cornerCodesMatchTheCalibration.

- [ ] M2: Goran's live click-through on the installed app (make install). Each of the 11 actions set from the app shows the same title in System Settings > Desktop & Dock > Hot Corners. A change made in Settings shows in the app the next time it opens. Switch off: Settings shows "-" for all four; switch on: the old corners come back, modifiers included. While off, choosing an item changes nothing in Settings until the switch goes on. Every control clicked twice, the drawing follows both times. Escape, a click outside and the status item each close the panel
  EVIDENCE: pending

- [ ] M3: the app's pop-up menu matches the Settings pop-up: same titles, same order, same separators (compare build/preview/menu.txt), and holding command shows the same modifier titles in both
  EVIDENCE: pending

- [ ] M4: visual review against the brandbook: glyph 16 pt and name in the header, the Disable HotCorners label and switch on their own row under the grid (on means all four are off), footer order, 18.25 pt circular corners, no animation, grid dimmed when off, notices readable, no blue anywhere including the open pop-up menu's highlight
  EVIDENCE: pending

- [ ] M5: Goran picked the corner mark (dot or stroke) from build/preview/glyph-*.png and the other variant is deleted
  EVIDENCE: pending

- [x] M6: Goran supplied Resources/AppIcon.png (1024 by 1024, the sigil in his chosen colour) and make icon built Resources/AppIcon.icns
  EVIDENCE: 2026-10-31 Goran supplied hotCorners-iOS-Default-1024@1x.icns (all 10 sizes, ink 96 to 927 px, the same dock fit as WidgetClock). Copied as Resources/AppIcon.icns; make icon extracts its 256 px slice as Resources/AppIcon.png for the README.

- [ ] M7: the antislop Delivery Gate report in .notes/ANTISLOP-GATE.md is PASS on every line, with evidence
  EVIDENCE: pending
