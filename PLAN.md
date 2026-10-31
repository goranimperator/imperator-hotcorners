# Imperator HotCorners Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Execution is **Native**, chosen by Goran on 2026-10-27: one session builds every task in order, and one fresh reviewer checks the whole repo at the end (Task 8 Step 10). **Do not start until Goran says go in chat.** Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A menu bar app, Imperator HotCorners, that shows the four macOS hot corners as four native pop-up buttons, changes them live the way System Settings does, and has an EQ-style header switch that turns every corner off and brings them back.

**Architecture:** A pure Swift library, `HotCornersCore`, holds the corner model, the store (state rules and the off-state snapshot) and a backend protocol whose real implementation calls the same two private HIServices functions System Settings calls, loaded with `dlsym`. A thin AppKit and SwiftUI executable, `ImperatorHotCorners`, draws the brandbook `MenuBarPanel` with header, a 2 by 2 grid of `NSPopUpButton`s and footer, and carries read-only self-checks (`--dock-check`, `--icon-check`, `--about-check`, `--render-preview`).

**Tech Stack:** Swift 6.4 in language mode 5, SwiftPM, AppKit, SwiftUI, Swift Testing, Make. macOS 26.0 minimum, universal binary.

**Spec:** `SPEC.md` (requirements R1 to R7, verified facts F1 to F11, open items U1 to U4, behaviour, UI, icon). Acceptance contract: `GATES.md`.

## Global Constraints

- Names: app "Imperator HotCorners"; package and executable `ImperatorHotCorners`; library `HotCornersCore`; tests `HotCornersCoreTests`; bundle id `com.goranimperator.ImperatorHotCorners`.
- Toolchain: `swift-tools-version:6.4`, `platforms: [.macOS("26.0")]`, `swiftSettings: [.swiftLanguageMode(.v5)]` last in every target, build with `--arch arm64 --arch x86_64`, sign with `Imperator Dev`.
- Design direction: `../imperator-apps-brandbook/BRANDBOOK.md`. Sections used: 2.6 AppColors, 6.1 MenuBarPanel, 7.1 HoverButton, 7.2 switches and LaunchAtLoginToggle, 9.1 header, 9.2 footer, 10 About, 14.1 dark, 14.2 accent (methods 2 and 3, SPM), 15 naming, 17 build. One deviation, from the spec: panel width 400 pt.
- English in every file, comment and UI string. No em dash and no en dash anywhere. UI strings use the curly apostrophe `’`, as Imperator EQ does.
- Git: `git init -b main` only. Never `git commit` or `git push` unless Goran says so in that message. Every task ends at a **Checkpoint**: report what passed, then wait.
- Live system safety: the agent never calls `CoreDockSetExposeCornerActionWithModifier` against the real Dock and never clicks the app's controls while it runs on the real backend; both change a system setting. Live writes happen only in Goran's own runs (Task 3 calibration, gate M2). Read-only runs are fine: `--dock-check`, the calibration dry run, `--render-preview`, launching the app. Tests use `InMemoryBackend` or fake closures, never the Dock.
- antislop: at the start of Tasks 6 and 7, load the skills `antislop`, `antislop-ui`, `antislop-human` and `antislop-copywriting` and apply them while building. Design Read: "Reading this as: a macOS menu bar utility panel for one power user, in the Imperator brandbook language, dial ENERGY 1 / RHYTHM 1 / MOTION 1" (a system surface: calm, uniform, hover opacity as the only motion). The Delivery Gate report closes Task 8 (gate M7).
- unlazy: `GATES.md` is the acceptance contract. Done means every runnable gate met with recorded evidence and every manual gate signed off by Goran.
- Tests: Swift Testing (`import Testing`), run with `swift test`.

## Review Focus

1. A corner with a modifier key set in Settings, such as ⌘ plus Mission Control, must show "⌘ Mission Control" and come back unchanged after off and on. Pinned by Task 4 `modifiersAndUnknownActionsSurviveOffAndOn` and Task 5 `alternateCarriesItsModifiers`.
2. A value the app does not know (15 from a future macOS, or the legacy 0) is shown honestly, never rewritten unless the user picks something, and survives off and on. Pinned by Task 1 `unknownActionIsKeptAndLabelled`, `legacyZeroReadsAsNoAction`, Task 4 `modifiersAndUnknownActionsSurviveOffAndOn`, Task 5 `unknownCurrentGetsItsOwnItem`.
3. Corners changed in System Settings while the app is off: Settings wins. Pinned by Task 4 `settingsChangeWhileOffWins`.
4. The Dock does not answer, or the functions are gone in a future macOS: no crash, a notice, controls disabled, nothing written. Pinned by Task 2 `readThrowsWhenTheDockDoesNotAnswer`, Task 4 `dockNotRespondingDisablesEditing` and `missingApiDisablesEverything`, Task 7 preview states.
5. One write failing halfway through switching off or on: earlier writes undone, no half state, notice shown. Pinned by Task 4 `failedWriteWhileSwitchingOffRollsBack`, `failedWriteWhileSwitchingOnStaysOff`, `failedChoiceShowsWhatTheDockKept`.

## Requirement coverage

| Req | What | Where it is built | Where it is proven |
|-----|------|-------------------|--------------------|
| R1 | Menu bar app on the Imperator base | Tasks 1, 6, 7, 8 | G1, G3, G4, G10, M4, M7 |
| R2 | Four selects, no picture | Task 7 | G8, M4 |
| R3 | Reads what Settings has | Tasks 2, 4 | G5, Task 4 `refreshShowsWhatSettingsHas`, M2 |
| R4 | Writes back, live, Settings agrees | Tasks 2, 3, 4 | M1, M2, Task 4 `choosingWhileOnWritesAtOnce` |
| R5 | Same UI as Settings: titles, order, modifiers | Tasks 1, 5, 7 | Task 1 `actionTitlesAndOrderMatchSystemSettings`, Task 5 tests, M3 |
| R6 | Header switch, off means "-" everywhere | Tasks 4, 6 | Task 4 switching tests, M2 |
| R7 | WidgetClock-style glyph with corner marks | Task 6 | G6, M5 |

## File map

| Path | Responsibility | Task |
|------|----------------|------|
| `SPEC.md`, `PLAN.md`, `GATES.md` | Design, this plan, acceptance gates (repo root, kept visible) | planning, 8 |
| `Package.swift`, `.gitignore`, `Makefile`, `LICENSE`, `CLAUDE.md` | Build, sign, bundle, release plumbing, project guide | 1, 8 |
| `Resources/Info.plist` | Bundle identity | 1 |
| `Resources/AppIcon.png`, `Resources/AppIcon.icns` | App icon, supplied by Goran, icns built by `make icon` | 8 |
| `Sources/HotCornersCore/CornerModel.swift` | `Corner`, `HotCornerAction`, `CornerModifiers`, `CornerSetting`, `CornerLayout` | 1 |
| `Sources/HotCornersCore/HotCornerBackend.swift` | `HotCornerBackend`, `DockError`, `InMemoryBackend` | 2 |
| `Sources/HotCornersCore/CoreDockBackend.swift` | The `dlsym` bridge to the Dock, corner codes | 2, 3 |
| `Sources/HotCornersCore/HotCornerStore.swift` | State rules, snapshot persistence | 4 |
| `Sources/HotCornersCore/CornerMenu.swift` | Pure menu model: sections, titles, modifier alternates | 5 |
| `Sources/ImperatorHotCorners/main.swift` | Check-mode dispatch, then the app | 1, 2, 6, 7 |
| `Sources/ImperatorHotCorners/AppDelegate.swift` | Status item, panel, store wiring | 6, 7 |
| `Sources/ImperatorHotCorners/MenuBarPanel.swift` | Brandbook 6.1 verbatim plus `refit()` | 6 |
| `Sources/ImperatorHotCorners/Theme.swift` | AppColors, brand switch, hover dimming, HoverButton, LaunchAtLoginToggle | 6 |
| `Sources/ImperatorHotCorners/StatusItemIcon.swift` | The glyph (frame plus four corner marks) | 6 |
| `Sources/ImperatorHotCorners/AboutPanel.swift` | About panel | 6 |
| `Sources/ImperatorHotCorners/DebugBackend.swift` | `#if DEBUG` fake Dock for safe click-testing | 6 |
| `Sources/ImperatorHotCorners/PopoverContentView.swift` | Header, notice, corner grid, footer | 6, 7 |
| `Sources/ImperatorHotCorners/CornerPopUp.swift` | `NSPopUpButton` wrapper fed by `CornerMenu` | 7 |
| `Sources/ImperatorHotCorners/Checks/*.swift` | `DockCheck`, `IconCheck`, `AboutCheck`, `PreviewRender` | 2, 6, 7 |
| `Tests/HotCornersCoreTests/*.swift` | Unit tests | 1, 2, 3, 4, 5 |
| `scripts/calibrate-dock.swift` | Supervised calibration of the write call | 3 |
| `scripts/check-dashes.mjs`, `scripts/check-brand.mjs` | Text and brand gates | 8 |
| `README.md` | Release README | 8 |

---

### Task 1: Package scaffold and corner model

**Files:**
- Create: `Package.swift`, `.gitignore`, `Resources/Info.plist`, `Makefile`, `LICENSE`, `CLAUDE.md`
- Create: `Sources/HotCornersCore/CornerModel.swift`
- Create: `Sources/ImperatorHotCorners/main.swift`
- Test: `Tests/HotCornersCoreTests/CornerModelTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  ```swift
  public enum Corner: Int, CaseIterable, Codable, Sendable {
      case topLeft = 0, topRight = 1, bottomLeft = 2, bottomRight = 3   // index in the Dock's arrays (F5)
      public var settingsName: String   // "Top Left Hot Corner" ... (F9), accessibility label
      public var shortName: String      // "top left" ..., used in the write-failed notice
  }
  public struct HotCornerAction: RawRepresentable, Hashable, Codable, Sendable {
      public let rawValue: Int32
      public init(rawValue: Int32)
      public static let legacyNoAction: HotCornerAction        // 0
      public static let noAction: HotCornerAction              // 1, title "-"
      public static let missionControl, applicationWindows, desktop, startScreenSaver,
                         disableScreenSaver, putDisplayToSleep, apps, notificationCenter,
                         lockScreen, quickNote: HotCornerAction   // 2, 3, 4, 5, 6, 10, 11, 12, 13, 14
      public static let menuSections: [[HotCornerAction]]      // Settings order, one array per separator group
      public var isKnown: Bool     // 0, or present in menuSections
      public var isActive: Bool    // neither 0 nor 1
      public var title: String     // Settings title; 0 gives "-"; unknown gives "Other (<raw>)"
  }
  public struct CornerModifiers: OptionSet, Hashable, Codable, Sendable {
      public let rawValue: Int32
      public static let shift, control, option, command: CornerModifiers   // 0x20000, 0x40000, 0x80000, 0x100000
      public static let dockMask: Int32                                    // 0x1E0000 (F7)
      public init(dockValue: Int32)                                        // dockValue & dockMask
      public var glyphs: String                                            // order ⌃ ⌥ ⇧ ⌘
      public static let allCombinations: [CornerModifiers]                 // 15 non-empty sets
  }
  public struct CornerSetting: Hashable, Codable, Sendable {
      public var action: HotCornerAction
      public var modifiers: CornerModifiers
      public init(action: HotCornerAction, modifiers: CornerModifiers)
      public static let noAction: CornerSetting      // (1, [])
      public var normalized: CornerSetting           // 0 becomes 1; "-" carries no modifiers
      public var title: String                       // "⌘ Mission Control", or the action title alone
  }
  public struct CornerLayout: Hashable, Codable, Sendable {
      public var topLeft, topRight, bottomLeft, bottomRight: CornerSetting
      public init(topLeft: CornerSetting, topRight: CornerSetting, bottomLeft: CornerSetting, bottomRight: CornerSetting)
      public init(dockActions: [Int32], dockModifiers: [Int32])   // both count 4, order TL TR BL BR
      public subscript(corner: Corner) -> CornerSetting { get set }
      public var dockActions: [Int32] { get }
      public var dockModifiers: [Int32] { get }
      public var hasActiveCorner: Bool { get }
      public static let allNoAction: CornerLayout
  }
  ```

- [ ] **Step 1: Initialise the repository**

Run: `git init -b main` in the repo root. No commit.

- [ ] **Step 2: Write `Package.swift`**

```swift
// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "ImperatorHotCorners",
    // Brandbook "Toolchain and SDK": the string form stamps minos 26.0 / sdk 26.0,
    // and the sdk field decides which generation of AppKit controls gets drawn.
    platforms: [.macOS("26.0")],
    targets: [
        .target(
            name: "HotCornersCore",
            path: "Sources/HotCornersCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "ImperatorHotCorners",
            dependencies: ["HotCornersCore"],
            path: "Sources/ImperatorHotCorners",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "HotCornersCoreTests",
            dependencies: ["HotCornersCore"],
            path: "Tests/HotCornersCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
```

- [ ] **Step 3: Write `.gitignore`**

Lines: `.DS_Store`, `.build/`, `.swiftpm/`, `build/`, `dist/`, `*.app`, `*.zip`, `.claude/settings.local.json`, `.unlazy/`, `.unlazy-hook-state.json`, `graphify-out/`.

- [ ] **Step 4: Write `Resources/Info.plist`**

| Key | Value |
|-----|-------|
| CFBundleDevelopmentRegion | `en` |
| CFBundleDisplayName | `Imperator HotCorners` |
| CFBundleName | `Imperator HotCorners` |
| CFBundleExecutable | `ImperatorHotCorners` |
| CFBundleIdentifier | `com.goranimperator.ImperatorHotCorners` |
| CFBundleIconFile | `AppIcon` |
| CFBundleInfoDictionaryVersion | `6.0` |
| CFBundlePackageType | `APPL` |
| CFBundleShortVersionString | `0.1.0` |
| CFBundleVersion | `1` |
| LSMinimumSystemVersion | `26.0` |
| LSUIElement | `true` |
| NSHighResolutionCapable | `true` |
| NSHumanReadableCopyright | `Copyright © 2026 Goran Imperator. MIT License.` |

Verify: `plutil -lint Resources/Info.plist` prints `OK`.

- [ ] **Step 5: Write the failing tests** in `Tests/HotCornersCoreTests/CornerModelTests.swift`

```swift
import Foundation
import Testing
@testable import HotCornersCore

@Test func cornerOrderMatchesTheDockArrays() {
    #expect(Corner.allCases.map(\.rawValue) == [0, 1, 2, 3])
    #expect(Corner.topLeft.settingsName == "Top Left Hot Corner")
    #expect(Corner.bottomRight.settingsName == "Bottom Right Hot Corner")
    #expect(Corner.topRight.shortName == "top right")
}

@Test func actionTitlesAndOrderMatchSystemSettings() {
    #expect(HotCornerAction.menuSections.map { $0.map(\.title) } == [
        ["Mission Control", "Application Windows", "Desktop", "Notification Center", "Apps", "Quick Note"],
        ["Start Screen Saver", "Disable Screen Saver"],
        ["Put Display to Sleep"],
        ["Lock Screen"],
        ["-"],
    ])
    #expect(HotCornerAction.menuSections.flatMap { $0 }.map(\.rawValue) == [2, 3, 4, 12, 11, 14, 5, 6, 10, 13, 1])
}

@Test func legacyZeroReadsAsNoAction() {
    #expect(HotCornerAction.legacyNoAction.title == "-")
    #expect(!HotCornerAction.legacyNoAction.isActive && !HotCornerAction.noAction.isActive)
    #expect(CornerSetting(action: .legacyNoAction, modifiers: [.command]).normalized == .noAction)
}

@Test func unknownActionIsKeptAndLabelled() {
    let future = HotCornerAction(rawValue: 15)
    #expect(future.isActive && !future.isKnown)
    #expect(future.title == "Other (15)")
}

@Test func modifiersUseTheSettingsMaskAndGlyphOrder() {
    #expect(CornerModifiers(dockValue: 0x100000 | 0x80000 | 0x1) == [.command, .option])
    #expect(CornerModifiers([.command, .shift, .option, .control]).glyphs == "⌃⌥⇧⌘")
    #expect(CornerModifiers.allCombinations.count == 15)
    #expect(Set(CornerModifiers.allCombinations).count == 15)
    #expect(!CornerModifiers.allCombinations.contains([]))
}

@Test func settingTitleShowsModifiersFirst() {
    #expect(CornerSetting(action: .missionControl, modifiers: [.command]).title == "⌘ Mission Control")
    #expect(CornerSetting.noAction.title == "-")
}

@Test func layoutRoundTripsTheDockArrays() {
    let layout = CornerLayout(dockActions: [2, 4, 11, 1], dockModifiers: [0, 0x100000, 0, 0])
    #expect(layout.topLeft.action == .missionControl)
    #expect(layout[.topRight] == CornerSetting(action: .desktop, modifiers: [.command]))
    #expect(layout.bottomLeft.action == .apps)
    #expect(layout.bottomRight == .noAction)
    #expect(layout.dockActions == [2, 4, 11, 1] && layout.dockModifiers == [0, 0x100000, 0, 0])
    #expect(layout.hasActiveCorner && !CornerLayout.allNoAction.hasActiveCorner)
}

@Test func layoutSurvivesJSON() throws {
    let layout = CornerLayout(dockActions: [15, 0, 13, 1], dockModifiers: [0x40000, 0, 0, 0])
    let decoded = try JSONDecoder().decode(CornerLayout.self, from: JSONEncoder().encode(layout))
    #expect(decoded == layout)
}
```

- [ ] **Step 6: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL, the compiler cannot find `Corner`, `HotCornerAction` and the other types.

- [ ] **Step 7: Implement `Sources/HotCornersCore/CornerModel.swift`** to the Interfaces block. `allCombinations` is the 15 non-empty subsets of `[control, option, shift, command]`, ordered by the bit pattern 1 to 15 with control as bit 0. `CornerLayout.init(dockActions:dockModifiers:)` keeps raw action values as they are (no normalising on read) and masks modifiers with `CornerModifiers(dockValue:)`. Codable comes from `RawRepresentable` with an `Int32` raw value; do not hand-write it.

- [ ] **Step 8: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS, 8 tests.

- [ ] **Step 9: Write `Sources/ImperatorHotCorners/main.swift`** as the accessory app entry: `NSApplication.shared`, `setActivationPolicy(.accessory)`, `run()`. Later tasks put check-mode dispatch above it and attach the delegate.

- [ ] **Step 10: Write the `Makefile`** (build part; Task 8 appends `dist` and `release`)

```make
APP_NAME     = Imperator HotCorners
BINARY_NAME  = ImperatorHotCorners
BUNDLE       = build/$(APP_NAME).app
DIST         = dist
ZIP          = $(DIST)/Imperator-HotCorners-$(VERSION).zip
BUILD_NUMBER = $(shell git rev-list --count HEAD 2>/dev/null || echo 1)
RELEASE_BUILD_NUMBER = $(shell git rev-list --count HEAD 2>/dev/null | awk '{print $$1 + 1}')
ARCHS        = --arch arm64 --arch x86_64
ICONSET      = build/AppIcon.iconset
# Self-signed, not ad-hoc: the login item registration is keyed to the
# designated requirement, and an ad-hoc cdhash changes on every build.
CODESIGN_IDENTITY ?= Imperator Dev

.PHONY: all build test icon install run clean

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

icon:
	@test -f Resources/AppIcon.png || { echo "Resources/AppIcon.png (1024x1024) is missing"; exit 1; }
	@rm -rf "$(ICONSET)" && mkdir -p "$(ICONSET)"
	for s in 16 32 128 256 512; do \
		sips -z $$s $$s Resources/AppIcon.png --out "$(ICONSET)/icon_$${s}x$${s}.png" >/dev/null; \
		sips -z $$((s*2)) $$((s*2)) Resources/AppIcon.png --out "$(ICONSET)/icon_$${s}x$${s}@2x.png" >/dev/null; \
	done
	iconutil -c icns "$(ICONSET)" -o Resources/AppIcon.icns

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
```

- [ ] **Step 11: Write `LICENSE`** (MIT, `Copyright (c) 2026 Goran Imperator`) **and `CLAUDE.md`**: what the app is; brandbook path and that it is the design direction; build, test and check commands; the Dock facts F2, F4, F6, F7 with a pointer to the spec; the Live system safety rule from Global Constraints; the git rule; English only, no em or en dashes.

- [ ] **Step 12: Build and check the bundle**

Run: `make build`
Expected: last line `Built: build/Imperator HotCorners.app`, plus the icon warning until gate M6.

Run the runnable gates G1, G3 and G4 from `GATES.md` by hand.
Expected: `G1_BUILD_SIGN_OK`, `G3_STAMP_OK`, `G4_PLIST_OK`.

- [ ] **Step 13: Checkpoint.** Report test and gate output to Goran. No commit.

---

### Task 2: Dock bridge, read path verified live

**Files:**
- Create: `Sources/HotCornersCore/HotCornerBackend.swift`
- Create: `Sources/HotCornersCore/CoreDockBackend.swift`
- Create: `Sources/ImperatorHotCorners/Checks/DockCheck.swift`
- Modify: `Sources/ImperatorHotCorners/main.swift` (dispatch `--dock-check` before the app starts)
- Test: `Tests/HotCornersCoreTests/CoreDockBackendTests.swift`

**Interfaces:**
- Consumes: `Corner`, `CornerSetting`, `CornerLayout` (Task 1).
- Produces:
  ```swift
  public protocol HotCornerBackend: AnyObject {
      func read() throws -> CornerLayout
      func write(_ setting: CornerSetting, to corner: Corner) throws
  }
  public enum DockError: Error, Equatable {
      case status(Int32)           // the Dock answered non-zero; -4956 means no reply within 3 s (F4)
      case notApplied(Corner)      // the call returned 0 but three read-backs still show something else
  }
  public final class InMemoryBackend: HotCornerBackend {
      public struct Write: Equatable { public let corner: Corner; public let setting: CornerSetting }
      public var layout: CornerLayout
      public var failReads: Bool                  // read() throws .status(-4956)
      public var failWrites: Set<Corner>          // write() to these throws .status(-1)
      public private(set) var writes: [Write]     // successful writes, normalized, in order
      public init(layout: CornerLayout)
  }
  public final class CoreDockBackend: HotCornerBackend {
      public typealias GetFunction = (UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
      public typealias SetFunction = (Int32, Int32, Int32) -> Int32   // (action, corner code, modifiers), F6
      public init(get: @escaping GetFunction, set: @escaping SetFunction, settleDelay: TimeInterval = 0.05)
      public static func system() -> CoreDockBackend?      // nil when either function is missing
      public static func cornerCode(_ corner: Corner) -> Int32
  }
  ```

- [ ] **Step 1: Write the failing tests** in `Tests/HotCornersCoreTests/CoreDockBackendTests.swift`

```swift
import Foundation
import Testing
@testable import HotCornersCore

/// A stand-in for the Dock: the two C functions as closures over four-slot arrays.
final class FakeDock {
    var actions: [Int32]
    var modifiers: [Int32]
    var getStatus: Int32 = 0
    var ignoreSets = false
    private(set) var reads = 0
    private(set) var calls: [[Int32]] = []

    init(_ actions: [Int32], _ modifiers: [Int32] = [0, 0, 0, 0]) {
        self.actions = actions
        self.modifiers = modifiers
    }

    func backend() -> CoreDockBackend {
        CoreDockBackend(
            get: { [self] a, m in
                reads += 1
                for i in 0..<4 { a[i] = actions[i]; m[i] = modifiers[i] }
                return getStatus
            },
            set: { [self] action, code, mods in
                calls.append([action, code, mods])
                guard !ignoreSets,
                      let i = Corner.allCases.firstIndex(where: { CoreDockBackend.cornerCode($0) == code })
                else { return 0 }
                actions[i] = action
                modifiers[i] = mods
                return 0
            },
            settleDelay: 0)
    }
}

@Test func readMapsTheDockArraysInOrder() throws {
    let dock = FakeDock([2, 4, 11, 1], [0, 0x100000, 0, 0])
    #expect(try dock.backend().read() == CornerLayout(dockActions: [2, 4, 11, 1], dockModifiers: [0, 0x100000, 0, 0]))
}

@Test func readThrowsWhenTheDockDoesNotAnswer() {
    let dock = FakeDock([1, 1, 1, 1])
    dock.getStatus = -4956
    #expect(throws: DockError.status(-4956)) { try dock.backend().read() }
}

@Test func writeSendsActionCornerModifiersInSettingsOrder() throws {
    let dock = FakeDock([2, 4, 11, 1])
    try dock.backend().write(CornerSetting(action: .desktop, modifiers: [.command]), to: .bottomLeft)
    #expect(dock.calls == [[4, CoreDockBackend.cornerCode(.bottomLeft), 0x100000]])
    #expect(dock.actions == [2, 4, 4, 1])
}

@Test func writeNormalizesTheLegacyNoAction() throws {
    let dock = FakeDock([2, 4, 11, 1])
    try dock.backend().write(CornerSetting(action: .legacyNoAction, modifiers: [.command]), to: .topLeft)
    #expect(dock.calls == [[1, CoreDockBackend.cornerCode(.topLeft), 0]])
}

@Test func writeThatDoesNotStickThrowsAfterThreeReads() {
    let dock = FakeDock([2, 4, 11, 1])
    dock.ignoreSets = true
    #expect(throws: DockError.notApplied(.topRight)) { try dock.backend().write(.noAction, to: .topRight) }
    #expect(dock.reads == 3)
}

@Test func cornerCodesAreDistinct() {
    #expect(Set(Corner.allCases.map(CoreDockBackend.cornerCode)).count == 4)
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL, `CoreDockBackend` and `DockError` not found.

- [ ] **Step 3: Implement `HotCornerBackend.swift`** to the Interfaces block. `InMemoryBackend.write` stores `setting.normalized` and appends to `writes` only on success.

- [ ] **Step 4: Implement `CoreDockBackend.swift`**
  - `system()`: `dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY)`, `dlsym` for `CoreDockGetExposeCornerActionsWithModifiers` and `CoreDockSetExposeCornerActionWithModifier`, `unsafeBitCast` each to a `@convention(c)` type with the signatures in F4 and F6, wrap them in the closures. Do not link the symbols directly: a macOS without them must still launch.
  - `read()`: two `[Int32]` buffers of 4, actions preset to 1 and modifiers to 0 (the Dock's own defaults, F4); non-zero status throws `.status`.
  - `write(_:to:)`: send `setting.normalized` as `(action.rawValue, cornerCode(corner), modifiers.rawValue)`; non-zero status throws `.status`; then read back up to 3 times, `settleDelay` apart, and return as soon as `read()[corner].normalized` equals the sent setting; otherwise throw `.notApplied(corner)`.
  - `cornerCode(_:)`: the hypothesis from spec U1 (top left 1, top right 2, bottom left 3, bottom right 4), with a comment that Task 3 replaces it with measured values.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS, 14 tests.

- [ ] **Step 6: Implement `DockCheck.run() -> Int32`** (read only, never calls the setter). Read through `CoreDockBackend.system()`; read `wvous-<tl|tr|bl|br>-corner` and `-modifier` from `com.apple.dock` with `CFPreferencesAppSynchronize` then `CFPreferencesCopyAppValue`; print one line per corner: `TL Mission Control (2, mods 0) prefs 2/0`. A missing pref key is printed as `prefs default` and not compared (a fresh account has none). Print `DOCK_CHECK_OK` and return 0 when every present key agrees; otherwise print `FAIL <corner> dock <a>/<m> prefs <a>/<m>` and return 1. Missing functions: print `FAIL CoreDock functions not found` and return 1.

- [ ] **Step 7: Verify against Goran's real corners (read only)**

Run: `swift build -c release && .build/release/ImperatorHotCorners --dock-check`
Expected on Goran's Mac today:
```
TL Mission Control (2, mods 0) prefs 2/0
TR Desktop (4, mods 0) prefs 4/0
BL Apps (11, mods 0) prefs 11/0
BR - (1, mods 0) prefs 1/0
DOCK_CHECK_OK
```

- [ ] **Step 8: Checkpoint.** No commit.

---

### Task 3: Calibrate the write call (Goran runs it)

Closes spec U1 and U2. The write path is not trusted until this task passes. If it fails, stop the plan.

**Files:**
- Create: `scripts/calibrate-dock.swift`
- Modify: `Sources/HotCornersCore/CoreDockBackend.swift` (corner codes; argument order only if the result says so)
- Modify: `Tests/HotCornersCoreTests/CoreDockBackendTests.swift`
- Modify: `CLAUDE.md` (record the result)

**Interfaces:**
- Consumes: the C signatures in spec F4 and F6.
- Produces: final `CoreDockBackend.cornerCode(_:)` values and argument order.

- [ ] **Step 1: Write `scripts/calibrate-dock.swift`**, a standalone script (`swift scripts/calibrate-dock.swift [--run]`) that loads the two functions with `dlsym` as in Task 2 and follows this algorithm exactly:

```text
S0 = get()                      abort with exit 1 if status != 0
print S0 per corner (title, raw action, raw modifiers)
print "To undo by hand: System Settings > Desktop & Dock > Hot Corners: TL=<title> TR=<title> BL=<title> BR=<title>"
T  = first of [12, 14, 6, 5] not in S0.actions
     (>= 5, so it can never be read as a corner code under either argument order;
      if all four are in use: print "NO_FREE_PROBE_ACTION", exit 6)
without --run: print T and the plan below, print "DRY_RUN_OK", exit 0. The setter is not even loaded.
with --run: read one line from stdin; continue only if it is "yes"

for order in [action-first (action, code, mods), code-first (code, action, mods)]:
    found = {}
    for c in [1, 2, 3, 4, 0, 8]:
        call set(T at action, c at corner, 0) in this order; sleep 0.3 s; S1 = get()
        changed = indices i where S1 differs from S0 in action or modifiers
        for each i in changed: set(S0.action[i] at action, c at corner, S0.mods[i]) in this order; sleep 0.3 s
        if get() != S0: print "RESTORE_FAILED" and the undo line, exit 2
        if changed == [i] and S1.action[i] == T: found[i] = c
        else if changed is not empty: print "AMBIGUOUS c=<c> changed=<changed>", exit 3
    if found has 4 entries:
        print "ORDER action,corner,modifiers" or "ORDER corner,action,modifiers"
        print "CORNER_CODES tl=<found[0]> tr=<found[1]> bl=<found[2]> br=<found[3]>"
        compare get() and the com.apple.dock wvous keys with S0; print "STATE_RESTORED" if equal, else "RESTORE_FAILED" and exit 2
        print "CALIBRATION_OK", exit 0
    if found has 1 to 3 entries: print "PARTIAL <found>", exit 4
print "CALIBRATION_FAILED: no corner changed under either order", exit 5
```

Each live change lasts under a second and is undone before the next probe.

- [ ] **Step 2: Dry run (agent, read only)**

Run: `swift scripts/calibrate-dock.swift`
Expected: Goran's four corners, `probe action 12`, `DRY_RUN_OK`.

- [ ] **Step 3: STOP and hand over to Goran.** This step changes a live system setting for a few seconds, so Goran runs it in his own terminal and types `yes` when asked:

```bash
swift scripts/calibrate-dock.swift --run
```

He pastes the output back. Expected on success: `ORDER ...`, `CORNER_CODES ...`, `STATE_RESTORED`, `CALIBRATION_OK`.

- [ ] **Step 4: Act on the result**
  - `CALIBRATION_FAILED` or `PARTIAL`: the Dock does not take the write from this app. Stop the plan, report to Goran, and re-plan with spec approach B. Do not start Task 4.
  - `RESTORE_FAILED` or `AMBIGUOUS`: Goran restores his corners in System Settings from the printed undo line; report and stop.
  - `ORDER corner,action,modifiers`: swap the first two arguments in `CoreDockBackend.write`, fix the `SetFunction` comment, and change `writeSendsActionCornerModifiersInSettingsOrder` to expect `[code, 4, 0x100000]` (and rename it).
  - `CALIBRATION_OK`: continue.

- [ ] **Step 5: Pin the measured codes.** Replace the hypothesis in `cornerCode(_:)` with the `CORNER_CODES` values and a comment naming the date and the macOS build. Add:

```swift
@Test func cornerCodesMatchTheCalibration() {
    // From `scripts/calibrate-dock.swift --run` on <date>, macOS <version> (<build>).
    #expect(Corner.allCases.map(CoreDockBackend.cornerCode) == [<tl>, <tr>, <bl>, <br>])
}
```

with the four measured numbers in place of the angle brackets.

- [ ] **Step 6: Run the tests**

Run: `swift test`
Expected: PASS, 15 tests.

- [ ] **Step 7: Record the result in `CLAUDE.md`** (order, codes, date, macOS build) and mark gate M1 with the pasted output as evidence.

- [ ] **Step 8: Checkpoint.** No commit.

---

### Task 4: The store

**Files:**
- Create: `Sources/HotCornersCore/HotCornerStore.swift`
- Test: `Tests/HotCornersCoreTests/HotCornerStoreTests.swift`

**Interfaces:**
- Consumes: `HotCornerBackend`, `InMemoryBackend`, `DockError` (Task 2); model types (Task 1).
- Produces:
  ```swift
  @MainActor
  public final class HotCornerStore: ObservableObject {
      public enum Problem: Equatable { case apiMissing, dockNotResponding, writeFailed(Corner) }
      @Published public private(set) var layout: CornerLayout      // starts as .allNoAction
      @Published public private(set) var isEnabled: Bool           // starts true
      @Published public private(set) var problem: Problem?         // starts .apiMissing when backend is nil
      public var canEdit: Bool { get }                             // false for .apiMissing and .dockNotResponding
      public static let snapshotKey: String                       // "disabledSnapshot"
      public init(backend: HotCornerBackend?, defaults: UserDefaults = .standard)
      public func refresh()
      public func choose(_ setting: CornerSetting, for corner: Corner)
      public func setEnabled(_ enabled: Bool)
  }
  ```

The rules are the spec's Behaviour section. The snapshot is `CornerLayout` as JSON `Data` under `snapshotKey`. `refresh()` sets `problem = nil` after a successful read. `choose` and `setEnabled` do nothing while `canEdit` is false, and `setEnabled` does nothing when asked for the state it is already in.

- [ ] **Step 1: Write the failing tests** in `Tests/HotCornersCoreTests/HotCornerStoreTests.swift`

```swift
import Foundation
import Testing
@testable import HotCornersCore

/// Goran's corners on 2026-10-27: Mission Control, Desktop, Apps, -.
private let goran = CornerLayout(dockActions: [2, 4, 11, 1], dockModifiers: [0, 0, 0, 0])

private func freshDefaults() -> UserDefaults {
    UserDefaults(suiteName: "HotCornersTests.\(UUID().uuidString)")!
}

@MainActor
private func makeStore(_ system: CornerLayout) -> (HotCornerStore, InMemoryBackend, UserDefaults) {
    let defaults = freshDefaults()
    let backend = InMemoryBackend(layout: system)
    let store = HotCornerStore(backend: backend, defaults: defaults)
    store.refresh()
    return (store, backend, defaults)
}

private func snapshot(_ defaults: UserDefaults) -> CornerLayout? {
    defaults.data(forKey: HotCornerStore.snapshotKey).flatMap { try? JSONDecoder().decode(CornerLayout.self, from: $0) }
}

@Test @MainActor func refreshShowsWhatSettingsHas() {
    let (store, backend, _) = makeStore(goran)
    #expect(store.layout == goran && store.isEnabled && store.problem == nil && backend.writes.isEmpty)
}

@Test @MainActor func switchingOffWritesNoActionToActiveCornersOnly() {
    let (store, backend, defaults) = makeStore(goran)
    store.setEnabled(false)
    #expect(backend.layout == .allNoAction)
    #expect(backend.writes.map(\.corner) == [.topLeft, .topRight, .bottomLeft])
    #expect(!store.isEnabled && store.layout == goran && snapshot(defaults) == goran)
}

@Test @MainActor func switchingOnRestoresTheSnapshot() {
    let (store, backend, defaults) = makeStore(goran)
    store.setEnabled(false)
    store.setEnabled(true)
    #expect(backend.layout == goran && store.isEnabled && snapshot(defaults) == nil)
}

@Test @MainActor func offStateSurvivesRelaunch() {
    let (store, backend, defaults) = makeStore(goran)
    store.setEnabled(false)
    let relaunched = HotCornerStore(backend: backend, defaults: defaults)
    relaunched.refresh()
    #expect(!relaunched.isEnabled && relaunched.layout == goran)
}

@Test @MainActor func settingsChangeWhileOffWins() {
    let (store, backend, defaults) = makeStore(goran)
    store.setEnabled(false)
    backend.layout[.topRight] = CornerSetting(action: .lockScreen, modifiers: [])
    store.refresh()
    #expect(store.isEnabled && store.layout == backend.layout && snapshot(defaults) == nil)
}

@Test @MainActor func choosingWhileOnWritesAtOnce() {
    let (store, backend, _) = makeStore(goran)
    let pick = CornerSetting(action: .lockScreen, modifiers: [.command])
    store.choose(pick, for: .bottomRight)
    #expect(backend.writes == [InMemoryBackend.Write(corner: .bottomRight, setting: pick)])
    #expect(store.layout.bottomRight == pick)
}

@Test @MainActor func choosingTheCurrentValueWritesNothing() {
    let (store, backend, _) = makeStore(goran)
    store.choose(goran.topLeft, for: .topLeft)
    #expect(backend.writes.isEmpty)
}

@Test @MainActor func choosingWhileOffOnlyEditsTheSnapshot() {
    let (store, backend, defaults) = makeStore(goran)
    store.setEnabled(false)
    let writesWhileOff = backend.writes.count
    store.choose(CornerSetting(action: .quickNote, modifiers: []), for: .topLeft)
    #expect(backend.writes.count == writesWhileOff)
    #expect(store.layout.topLeft.action == .quickNote && snapshot(defaults)?.topLeft.action == .quickNote)
    store.setEnabled(true)
    #expect(backend.layout.topLeft.action == .quickNote)
}

@Test @MainActor func modifiersAndUnknownActionsSurviveOffAndOn() {
    let system = CornerLayout(dockActions: [15, 2, 0, 1], dockModifiers: [0x40000, 0x100000, 0, 0])
    let (store, backend, _) = makeStore(system)
    store.setEnabled(false)
    store.setEnabled(true)
    #expect(backend.layout == system)
}

@Test @MainActor func failedWriteWhileSwitchingOffRollsBack() {
    let (store, backend, defaults) = makeStore(goran)
    backend.failWrites = [.topRight]
    store.setEnabled(false)
    #expect(store.isEnabled && store.problem == .writeFailed(.topRight))
    #expect(backend.layout == goran && snapshot(defaults) == nil)
}

@Test @MainActor func failedWriteWhileSwitchingOnStaysOff() {
    let (store, backend, defaults) = makeStore(goran)
    store.setEnabled(false)
    backend.failWrites = [.bottomLeft]
    store.setEnabled(true)
    #expect(!store.isEnabled && store.problem == .writeFailed(.bottomLeft))
    #expect(backend.layout == .allNoAction && snapshot(defaults) == goran)
}

@Test @MainActor func failedChoiceShowsWhatTheDockKept() {
    let (store, backend, _) = makeStore(goran)
    backend.failWrites = [.topLeft]
    store.choose(CornerSetting(action: .desktop, modifiers: []), for: .topLeft)
    #expect(store.problem == .writeFailed(.topLeft) && store.layout.topLeft == goran.topLeft)
}

@Test @MainActor func dockNotRespondingDisablesEditing() {
    let (store, backend, _) = makeStore(goran)
    backend.failReads = true
    store.refresh()
    store.choose(CornerSetting(action: .desktop, modifiers: []), for: .topLeft)
    #expect(store.problem == .dockNotResponding && !store.canEdit && backend.writes.isEmpty)
}

@Test @MainActor func missingApiDisablesEverything() {
    let store = HotCornerStore(backend: nil, defaults: freshDefaults())
    store.refresh()
    store.setEnabled(false)
    #expect(store.problem == .apiMissing && store.isEnabled && !store.canEdit)
}

@Test @MainActor func switchingOffWithNothingActiveStillTurnsOff() {
    let (store, backend, _) = makeStore(.allNoAction)
    store.setEnabled(false)
    #expect(!store.isEnabled && backend.writes.isEmpty)
}

@Test @MainActor func corruptSnapshotIsDropped() {
    let defaults = freshDefaults()
    defaults.set(Data("not json".utf8), forKey: HotCornerStore.snapshotKey)
    let store = HotCornerStore(backend: InMemoryBackend(layout: .allNoAction), defaults: defaults)
    store.refresh()
    #expect(store.isEnabled && defaults.data(forKey: HotCornerStore.snapshotKey) == nil)
}

@Test @MainActor func successfulRefreshClearsTheProblem() {
    let (store, backend, _) = makeStore(goran)
    backend.failReads = true
    store.refresh()
    backend.failReads = false
    store.refresh()
    #expect(store.problem == nil && store.canEdit)
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL, `HotCornerStore` not found.

- [ ] **Step 3: Implement `HotCornerStore.swift`** to the Interfaces block and the spec's Behaviour section. Switching off and on are each one read followed by writes in `Corner.allCases` order; on the first failed write, write the original value back to every corner already changed in that step (ignoring errors), then set `problem = .writeFailed(corner)` and leave `isEnabled` and the saved snapshot as they were. A failed `choose` re-reads the Dock for `layout` and keeps the problem.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS, 32 tests.

- [ ] **Step 5: Checkpoint.** No commit.

---

### Task 5: Menu model with modifier alternates

**Files:**
- Create: `Sources/HotCornersCore/CornerMenu.swift`
- Test: `Tests/HotCornersCoreTests/CornerMenuTests.swift`

**Interfaces:**
- Consumes: model types (Task 1).
- Produces:
  ```swift
  public struct CornerMenuItem: Equatable, Sendable {
      public let setting: CornerSetting
      public let title: String
      public let isAlternate: Bool     // AppKit shows it only while exactly setting.modifiers are held
      public init(setting: CornerSetting, title: String, isAlternate: Bool)
  }
  public struct MenuPosition: Equatable, Sendable { public let section: Int; public let item: Int }
  public enum CornerMenu {
      public static func sections(current: CornerSetting) -> [[CornerMenuItem]]
      public static func position(of setting: CornerSetting, in sections: [[CornerMenuItem]]) -> MenuPosition?
  }
  ```

Rules: one section per `HotCornerAction.menuSections` group. Every action except "-" gives a base item (no modifiers, `isAlternate` false) followed by 15 alternates in `CornerModifiers.allCombinations` order, titled with `CornerSetting.title`. "-" gives one item and no alternates. When `current.normalized` matches no item (an unknown action), a first section holding only `current` is prepended so the pop-up can show it. `position(of:in:)` compares `normalized` settings.

- [ ] **Step 1: Write the failing tests** in `Tests/HotCornersCoreTests/CornerMenuTests.swift`

```swift
import Testing
@testable import HotCornersCore

@Test func sectionsMirrorSettingsWithAlternates() {
    let sections = CornerMenu.sections(current: .noAction)
    #expect(sections.map(\.count) == [96, 32, 16, 16, 1])
    #expect(sections.map { $0.filter { !$0.isAlternate }.map(\.title) } == [
        ["Mission Control", "Application Windows", "Desktop", "Notification Center", "Apps", "Quick Note"],
        ["Start Screen Saver", "Disable Screen Saver"],
        ["Put Display to Sleep"],
        ["Lock Screen"],
        ["-"],
    ])
}

@Test func alternateCarriesItsModifiers() {
    let missionControl = Array(CornerMenu.sections(current: .noAction)[0][0..<16])
    #expect(missionControl[0] == CornerMenuItem(setting: CornerSetting(action: .missionControl, modifiers: []),
                                                title: "Mission Control", isAlternate: false))
    #expect(missionControl.dropFirst().allSatisfy { $0.isAlternate && $0.setting.action == .missionControl })
    #expect(missionControl.contains(CornerMenuItem(setting: CornerSetting(action: .missionControl, modifiers: [.command]),
                                                   title: "⌘ Mission Control", isAlternate: true)))
    #expect(missionControl.contains { $0.title == "⌃⌥⇧⌘ Mission Control" })
}

@Test func noActionHasNoAlternates() {
    #expect(CornerMenu.sections(current: .noAction).last == [CornerMenuItem(setting: .noAction, title: "-", isAlternate: false)])
}

@Test func unknownCurrentGetsItsOwnItem() {
    let odd = CornerSetting(action: HotCornerAction(rawValue: 15), modifiers: [])
    let sections = CornerMenu.sections(current: odd)
    #expect(sections.count == 6)
    #expect(sections[0] == [CornerMenuItem(setting: odd, title: "Other (15)", isAlternate: false)])
    #expect(CornerMenu.position(of: odd, in: sections) == MenuPosition(section: 0, item: 0))
}

@Test func positionFindsModifiedAndLegacyValues() {
    let sections = CornerMenu.sections(current: .noAction)
    let modified = CornerMenu.position(of: CornerSetting(action: .desktop, modifiers: [.command]), in: sections)!
    #expect(sections[modified.section][modified.item].title == "⌘ Desktop")
    let legacy = CornerMenu.position(of: CornerSetting(action: .legacyNoAction, modifiers: []), in: sections)!
    #expect(sections[legacy.section][legacy.item].title == "-")
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test`
Expected: FAIL, `CornerMenu` not found.

- [ ] **Step 3: Implement `CornerMenu.swift`** to the rules above.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test`
Expected: PASS, 37 tests.

- [ ] **Step 5: Checkpoint.** No commit.

---

### Task 6: App shell, glyph and self-checks

Load `antislop`, `antislop-ui`, `antislop-human`, `antislop-copywriting` before Step 1.

**Files:**
- Create: `Sources/ImperatorHotCorners/Theme.swift`, `MenuBarPanel.swift`, `StatusItemIcon.swift`, `AboutPanel.swift`, `AppDelegate.swift`, `DebugBackend.swift`, `PopoverContentView.swift`
- Create: `Sources/ImperatorHotCorners/Checks/IconCheck.swift`, `Checks/AboutCheck.swift`
- Modify: `Sources/ImperatorHotCorners/main.swift`

**Interfaces:**
- Consumes: `HotCornerStore` (Task 4), `CoreDockBackend.system()` and `InMemoryBackend` (Task 2).
- Produces:
  ```swift
  enum StatusItemIcon {
      enum CornerMark { case dot, stroke }            // gate M5 keeps one
      static func make(size: CGFloat = 18, mark: CornerMark = .dot) -> NSImage   // template
  }
  final class MenuBarPanel: NSPanel {                  // brandbook 6.1 verbatim, plus:
      func refit()        // re-measure the content and keep the top edge where it is
  }
  struct PopoverContentView: View {
      static let width: CGFloat = 400
      @ObservedObject var store: HotCornerStore
      let dismissAction: () -> Void
      let quitAction: () -> Void
  }
  enum IconCheck { static func run() -> Int32 }       // prints ICON_CHECK_OK
  enum AboutCheck { static func run() -> Int32 }      // prints ABOUT_PANEL_OK
  ```

- [ ] **Step 1: Copy the brand pieces.** `Theme.swift`: `AppColors` from `../imperator-eq/Sources/ImperatorEQ/Theme.swift` plus `brandNS` from brandbook 2.6; `LaunchAtLoginToggle`, `HoverButton`, `HoverDimmed`, `brandSwitch(anchor:)` and `hoverDimmed()` from `../imperator-eq/Sources/ImperatorEQ/PopoverContentView.swift` (lines 244 to 282 and 403 to 431). `MenuBarPanel.swift`: the class in BRANDBOOK.md 6.1 verbatim, plus `refit()`. `AboutPanel.swift` and `Checks/AboutCheck.swift`: copy EQ's files and replace "Imperator EQ" with "Imperator HotCorners" everywhere.

- [ ] **Step 2: Write `StatusItemIcon`** to the spec's Icon section: the frame by WidgetClock's formula (ink `x = ((size - size * 16/18) / 2).rounded()`, `y = ((size - size * 12/18) / 2).rounded()`, `width = (size * 16/18).rounded()`, `height = (size * 12/18).rounded()`, stroke `size * 1.125/18`, radius `size * 1.7/18 - stroke / 2`, round line join), then the four marks. Dot: 2 by 2 pt filled squares whose outer corners sit 2 pt inside the frame's outer corners. Stroke: from those same four points, a line 1.75 pt toward the centre on each axis, frame stroke width, round caps. `isTemplate = true`.

- [ ] **Step 3: Write `IconCheck.run()`** that renders `make()` for both marks at 18 and 16 pt and measures pixels, the way `../imperator-widget-clock/Sources/ImperatorClock/IconCheck.swift` does. Assert: canvas is size by size and template; at 4x the frame's ink box is within 0.25 pt of the formula's box; the marks are mirror-symmetric (left and right gaps to the frame equal, top and bottom equal, within 0.01 pt at 2x); for the dot mark at 1x every edge lies on a whole pixel. Print every failure as `FAIL <reason>`; print `ICON_CHECK_OK` and return 0 only when there are none.

- [ ] **Step 4: Write `DebugBackend.swift`**, all of it inside `#if DEBUG`: when the environment has `IMPERATOR_HOTCORNERS_FAKE=1`, the app uses an `InMemoryBackend` starting at Goran's layout (2, 4, 11, 1); `IMPERATOR_HOTCORNERS_FAKE_FAIL` takes `reads` or a comma list of `tl,tr,bl,br` and sets `failReads` or `failWrites`. This lets Goran click every state without touching his real corners. Gate G11 proves it is gone from release builds.

- [ ] **Step 5: Write `AppDelegate`** to brandbook 18.1 and EQ's `AppDelegate`: dark appearance, `AppleAccentColor` 0, process name "Imperator HotCorners"; `store = HotCornerStore(backend: <DEBUG fake if set, else CoreDockBackend.system()>)` then `store.refresh()`; a `.squareLength` status item with `StatusItemIcon.make()`, tooltip and accessibility label "Imperator HotCorners"; a `MenuBarPanel` of width `PopoverContentView.width`. Before every show: `store.refresh()`, then `panel.show(from:)` and `NSApp.activate(ignoringOtherApps: true)`. Subscribe to `store.$problem.removeDuplicates()` and call `panel.refit()` while the panel is shown.

- [ ] **Step 6: Write `PopoverContentView`** with the final header and footer and an empty content area that Task 7 fills. Header, brandbook 9.1: `HStack(spacing: 8)` of `Image(nsImage: StatusItemIcon.make(size: 16)).renderingMode(.template)`, `Text("Imperator HotCorners").font(.headline)`, `Spacer()`, and `Toggle("", isOn: <get store.isEnabled, set store.setEnabled>)` with `.brandSwitch(anchor: .trailing)`, `.disabled(!store.canEdit)` and accessibility label "Hot Corners"; padding 16 by 12. Footer, brandbook 9.2 and EQ: `LaunchAtLoginToggle`, `Spacer`, `HoverButton` "About" (calls `dismissAction()` then `AboutPanel.show()`, help "About Imperator HotCorners"), `HoverButton` "Quit"; padding 16 by 10. Dividers between. `.frame(width: Self.width)`, `.fixedSize(horizontal: false, vertical: true)`, `.background(AppColors.popoverBackground)`.

- [ ] **Step 7: Dispatch the checks in `main.swift`**: `--icon-check`, `--about-check` (both on the main actor, as EQ does) and `--dock-check`, each exiting with its return code; otherwise attach `AppDelegate` and run.

- [ ] **Step 8: Build and run the checks**

Run: `make build` then the G6 and G11 commands from `GATES.md`.
Expected: `ICON_CHECK_OK`, `G11_NO_DEBUG_OK`. G7 (`ABOUT_PANEL_OK`) passes once gate M6 has put the app icon in the bundle; until then it fails only on the icon line.

- [ ] **Step 9: Launch for a look (read only).** Run `make run`. The glyph appears in the menu bar and the panel opens and closes from it. Do not touch the switch: it is live. Goran checks with `IMPERATOR_HOTCORNERS_FAKE=1` on a debug build (`swift build && IMPERATOR_HOTCORNERS_FAKE=1 .build/debug/ImperatorHotCorners`) if he wants to click.

- [ ] **Step 10: Checkpoint.** No commit.

---

### Task 7: Corner grid, notices and preview

Keep the antislop skills loaded from Task 6.

**Files:**
- Create: `Sources/ImperatorHotCorners/CornerPopUp.swift`
- Create: `Sources/ImperatorHotCorners/Checks/PreviewRender.swift`
- Modify: `Sources/ImperatorHotCorners/PopoverContentView.swift` (content area)
- Modify: `Sources/ImperatorHotCorners/main.swift` (dispatch `--render-preview <dir>`)

**Interfaces:**
- Consumes: `CornerMenu`, `CornerMenuItem`, `MenuPosition` (Task 5); `HotCornerStore` (Task 4); `PopoverContentView` (Task 6).
- Produces:
  ```swift
  struct CornerPopUp: NSViewRepresentable {
      static let columnWidth: CGFloat = 178      // (400 - 2 * 16 - 12) / 2
      let corner: Corner
      let setting: CornerSetting
      let isEnabled: Bool
      let onChoose: (CornerSetting) -> Void
  }
  enum PreviewRender { static func run(directory: String) -> Int32 }   // prints PREVIEW_OK
  ```

- [ ] **Step 1: Write `CornerPopUp`.** `makeNSView` returns a non-pull-down `NSPopUpButton`, `controlSize = .regular`, target and action on the coordinator, accessibility label `corner.settingsName`. `updateNSView` rebuilds the menu only when `setting` changed since the last build: for each section of `CornerMenu.sections(current: setting)`, a separator between sections, one `NSMenuItem` per item with `isAlternate` and `keyEquivalentModifierMask` set from the item (alternates keep an empty key equivalent), and the flat item index in `tag`; then selects `CornerMenu.position(of: setting, ...)`, sets `toolTip = setting.title` and `isEnabled`. The coordinator maps the chosen item's `tag` back to its `CornerMenuItem` and calls `onChoose(item.setting)`.

- [ ] **Step 2: Fill the content area of `PopoverContentView`.** `VStack(alignment: .leading, spacing: 12)` with padding 16 holding the notice (when `store.problem` is not nil) and then `Grid(horizontalSpacing: 12, verticalSpacing: 8)` with two `GridRow`s: top left and top right, then bottom left and bottom right, each a `CornerPopUp` with `.frame(maxWidth: .infinity)`, `isEnabled: store.canEdit`, `onChoose: { store.choose($0, for: corner) }`. The grid gets `.opacity(store.isEnabled ? 1 : 0.3)`. Notice: EQ's `notice(title:body:)` layout (`.caption.weight(.semibold)` title in `.primary`, `.caption` body in `.secondary`, a `.bordered` `.small` button), with exactly the copy in the spec's UI section. "Open Desktop & Dock Settings" opens `x-apple.systempreferences:com.apple.Desktop-Settings.extension`; "Try Again" calls `store.refresh()`. The write-failed title uses `corner.shortName`.

- [ ] **Step 3: Write `PreviewRender.run(directory:)`.** Dark appearance; host `PopoverContentView` in an offscreen borderless `NSWindow` (not ordered front) at width 400 over a solid dark stand-in background (the visual effect material does not render offscreen); `layoutSubtreeIfNeeded()`; `cacheDisplay(in:to:)`; write PNGs at 2x for these stores (each an `InMemoryBackend` plus `HotCornerStore`, refreshed): `panel-on` (Goran's layout), `panel-off` (switched off), `panel-modifiers` (⌘ Mission Control, ⌥ Desktop, ⌃⇧ Apps, -), `panel-longest` (Disable Screen Saver, Application Windows, Put Display to Sleep, Notification Center), `panel-dock-not-responding`, `panel-write-failed` (top left), `panel-api-missing` (backend nil). Write the glyph for both marks at 18 and 16 pt, 1x and 2x, tinted black on white and white on black (`glyph-<mark>-<size>@<scale>x-<light|dark>.png`). Write `menu.txt`: the base titles of `CornerMenu.sections(current: .noAction)` with `---` between sections. Fit check: for every title in `HotCornerAction.menuSections`, a one-item regular `NSPopUpButton` after `sizeToFit()` must be at most `CornerPopUp.columnWidth` wide; print `FAIL fit <title> <width>` otherwise. Print `PREVIEW_OK` and return 0 when every file is written and every title fits.

- [ ] **Step 4: Run the preview**

Run: `make build` then `"build/Imperator HotCorners.app/Contents/MacOS/ImperatorHotCorners" --render-preview build/preview`
Expected: `PREVIEW_OK`. Open every PNG with the Read tool and check against the brandbook and antislop rules: header order, switch at the trailing edge, grid alignment, dimmed grid in `panel-off`, notice wording, no clipped titles in `panel-longest`.

- [ ] **Step 5: Verify modifier alternates (spec U4) with Goran.** On a debug build with the fake backend (`IMPERATOR_HOTCORNERS_FAKE=1`), Goran opens a pop-up and holds ⌘: the items read "⌘ Mission Control" and so on, and choosing one shows that title. If alternates do not appear in an `NSPopUpButton`: keep the base items only, and in the coordinator read `NSEvent.modifierFlags` at the moment of choosing, masked to ⌃⌥⇧⌘, as the chosen modifiers. Record which path shipped in `CLAUDE.md`.

- [ ] **Step 6: Checkpoint.** Show Goran the preview PNGs (gates M4 and M5 start here). No commit.

---

### Task 8: Release readiness, gates and sign-off

**Files:**
- Create: `scripts/check-dashes.mjs`, `scripts/check-brand.mjs`, `README.md`
- Modify: `Makefile` (append `check-version`, `dist`, `release`), `CLAUDE.md` (final), `StatusItemIcon.swift` (drop the losing mark after M5), `GATES.md` (evidence)
- Create: `ANTISLOP-GATE.md` (Delivery Gate report)
- Add: `Resources/AppIcon.png` from Goran, `Resources/AppIcon.icns` from `make icon`

- [ ] **Step 1: Write `scripts/check-dashes.mjs`.** Walk `Sources`, `Tests`, `scripts`, `Resources/Info.plist`, `SPEC.md`, `PLAN.md`, `GATES.md`, `ANTISLOP-GATE.md` (once it exists), `README.md`, `CLAUDE.md`, `Makefile`; fail on any U+2014 or U+2013 with `file:line`; print `DASHES_OK` otherwise. Positive control in the same script: it first writes a temp file containing U+2014 and asserts its own scanner flags it; if not, print `FAIL scanner control` and exit 1.

- [ ] **Step 2: Write `scripts/check-brand.mjs`.** In `Sources/ImperatorHotCorners`: no `accentColor` except inside the string `"AppleAccentColor"`, no `NSPopover`, `.cursor(.pointingHand)` never on a `Toggle`, and `AppleAccentColor` set in `AppDelegate.swift`. Same positive-control pattern with a temp fixture holding `Color.accentColor`. Print `BRAND_OK`.

- [ ] **Step 3: Append the release targets to the `Makefile`:** `check-version`, `dist` and `release`, copied from `../imperator-widget-clock/Makefile` lines 180 to 219 without the widget lines (no `APPEX`, no `WidgetInfo.plist`), with `NOTES ?=` describing this app and the same `GATEKEEPER` text. `release` stays unrun; it belongs to the `imperator-release` skill and Goran's word.

- [ ] **Step 4: Goran supplies the app icon (gate M6).** He makes the sigil icon in his chosen colour as for the other apps (Icon Composer, then Imperator AppIcons) and drops the 1024 by 1024 PNG at `Resources/AppIcon.png`. Run: `make icon`. Expected: `Resources/AppIcon.icns` exists.

- [ ] **Step 5: Goran picks the corner mark (gate M5)** from the `glyph-*` PNGs. Delete the other `CornerMark` case and its drawing; `IconCheck` then checks the one left.

- [ ] **Step 6: Write `README.md`** to the `imperator-release` skill's Phase 1 item 9: icon and title, what it does, install (with the Gatekeeper note), how to use it (the four pop-ups, the switch, holding modifier keys), how it works (the same Dock calls System Settings uses, no Dock restart), requirements (macOS 26 or later, Apple silicon and Intel), build, license.

- [ ] **Step 7: Run every runnable gate**

Run: `node ~/.claude/skills/unlazy/scripts/gate-check.mjs --status GATES.md`, review each command, then `node ~/.claude/skills/unlazy/scripts/gate-check.mjs --approve GATES.md`
Expected: G1 to G12 met with evidence.

- [ ] **Step 8: Manual gates with Goran** (wording in `GATES.md`): M2 live click-through on the installed app (`make install`), M3 menu comparison against System Settings, M4 visual review. Record his results as evidence.

- [ ] **Step 9: antislop Delivery Gate (gate M7).** Write the PASS/FAIL report, one line per item with evidence, to `ANTISLOP-GATE.md` in the repo root. The R-35 click-through evidence is Goran's M2 record.

- [ ] **Step 10: Fresh review, the one independent check in Native.** Dispatch one fresh reviewer agent on the most capable model. Give it only `SPEC.md`, `PLAN.md`, `GATES.md` and the repo, and ask for correctness bugs against the spec's Behaviour section and this plan's Review Focus list. Fix every finding it confirms, then re-run `swift test` and gates G1 to G12. Record the findings and fixes in the final report.

- [ ] **Step 11: Final checkpoint.** Report measured gate counts (met, unmet, abandoned) and every abandonment. No commit, no tag, no release until Goran says so.
