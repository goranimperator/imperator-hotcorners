# Imperator HotCorners: design

Date: 2026-10-27. Measured on macOS 27.2 (26B123), Xcode 27.1, Swift 6.4, Apple silicon.
Implementation plan: `PLAN.md`.
Acceptance gates: `GATES.md`.

## Intent

Hot corners live three levels deep in System Settings (Desktop & Dock, then the Hot Corners... button, then a sheet). Imperator HotCorners puts the same four pop-up buttons in the menu bar, in the Imperator family look, plus one switch that turns every corner off and brings them back.

## Requirements (from Goran)

- R1. A menu bar app named **Imperator HotCorners**, on the same base as the other Imperator apps: `../imperator-apps-brandbook/BRANDBOOK.md` is the design direction and the single source of truth.
- R2. Four selects, one per corner. No picture in the middle.
- R3. Reads the current hot corners from the system. Corners already set in System Settings show up in the app.
- R4. Writes changes back, so they take effect at once and System Settings shows the same values.
- R5. Same UI as Settings: native pop-up buttons, the same titles, the same order.
- R6. A switch in the header like Imperator EQ's. Off disables every corner, which is the same as choosing "-" for all four.
- R7. Icon like Imperator WidgetClock's menu bar glyph, with a dot or a short stroke in each corner.

## Non-goals

- Global keyboard shortcut, presets or profiles.
- Per-display corners (macOS has one set for all displays).
- Any Dock setting other than the four corners and their modifier keys.
- A "Done" button: changes apply on selection, as they do in Settings.

## Anti-goals (failure even if it works)

- Restarting the Dock (`killall Dock`) for a normal change.
- Writing a corner the user did not touch.
- Losing a modifier key or an unknown (future) action when the switch goes off and on.
- Any blue in the UI, including the open menu's highlight.

## Verified facts

| # | Fact | How it was measured |
|---|------|---------------------|
| F1 | The Dock stores corners in `com.apple.dock` as `wvous-tl-corner`, `wvous-tr-corner`, `wvous-bl-corner`, `wvous-br-corner` and matching `wvous-*-modifier` keys. | `defaults read com.apple.dock`: tl=2, tr=4, bl=11, br=1, modifiers 0, exactly what Goran's Settings screenshot shows (Mission Control, Desktop, Apps, -). |
| F2 | System Settings reads and writes corners with two private HIServices functions, not with `defaults` and not with a Dock restart. | `dyld_info -imports` on `/System/Library/ExtensionKit/Extensions/DesktopSettings.appex`: `_CoreDockGetExposeCornerActionsWithModifiers` and `_CoreDockSetExposeCornerActionWithModifier` (from ApplicationServices). |
| F3 | Both functions are exported by HIServices and listed in the SDK's `HIServices.tbd`. | `dyld_info -exports` on HIServices; grep of the SDK tbd. |
| F4 | `int32_t CoreDockGetExposeCornerActionsWithModifiers(int32_t actions[4], int32_t modifiers[4])`. A Mach call to the Dock with a 3000 ms timeout; returns 0 on success and -4956 when the Dock does not reply. The actions array defaults to `{1,1,1,1}`. | `lldb` disassembly of the function; memory read of its default constant. |
| F5 | The arrays are ordered top left, top right, bottom left, bottom right, and the call works from an unsigned, unsandboxed process. Average latency 0.05 ms. | Probe in the session scratchpad: `status=0 actions=2,4,11,1 modifiers=0,0,0,0`; 200 calls timed. |
| F6 | `int32_t CoreDockSetExposeCornerActionWithModifier(int32_t, int32_t, int32_t)` is a Mach call to the Dock with the same 3000 ms timeout and status codes. System Settings passes **(action, corner, modifiers)**. | Disassembly of the Settings call site (`lsr x0, x22, #32` puts the action in the first argument) and the Swift field order of its `HotCornerShortcut` (`corner`, `action`, `modifiers`). The Dock's own selector is `_setCornerActionWithModifier:modifier:corner:`. |
| F7 | Modifiers are `NSEvent.ModifierFlags` bits and Settings keeps only `0x1E0000`: shift `0x20000`, control `0x40000`, option `0x80000`, command `0x100000`. | `and w1, w24, #0x1e0000` in the Settings binary. |
| F8 | Action values: 1 "-", 2 Mission Control, 3 Application Windows, 4 Desktop, 5 Start Screen Saver, 6 Disable Screen Saver, 10 Put Display to Sleep, 11 Apps, 12 Notification Center, 13 Lock Screen, 14 Quick Note. 0 is the legacy "no-op" and means the same as "-". | 1, 2, 4 and 11 measured live (F1, F5); 11 shows as "Apps" in macOS 27 Settings. The rest are community-documented values, confirmed in the live click-through (gate M2). |
| F9 | Settings' English titles are exactly: Mission Control, Application Windows, Desktop, Notification Center, Apps, Quick Note, Start Screen Saver, Disable Screen Saver, Put Display to Sleep, Lock Screen, and "-". Accessibility names: "Top Left Hot Corner", "Top Right Hot Corner", "Bottom Left Hot Corner", "Bottom Right Hot Corner". | `Localizable.loctable` of DesktopSettings.appex. |
| F10 | Desktop & Dock opens with `x-apple.systempreferences:com.apple.Desktop-Settings.extension`. | The extension's Info.plist: `allowsXAppleSystemPreferencesURLScheme = true`. |
| F11 | At regular control size a pop-up button needs up to 176 pt for its longest title ("Disable Screen Saver"); "Application Windows" 174, "Put Display to Sleep" 169, "Notification Center" 162. A "⌘ " prefix adds about 16 pt. | `NSPopUpButton.sizeToFit()` per title, dark appearance. |

## Still open, closed by gates

- U1. The corner codes `CoreDockSetExposeCornerActionWithModifier` expects (hypothesis: top left 1, top right 2, bottom left 3, bottom right 4). Closed by the supervised calibration (plan Task 3, gate M1).
- U2. Whether the Dock accepts the write from a third-party app signed `Imperator Dev`. The read works (F5), so the same server very likely takes the write. Closed by M1. If it does not, the plan stops and approach B below is planned instead.
- U3. Menu order and separators in Settings' pop-up. Plan default from earlier macOS releases: Mission Control, Application Windows, Desktop, Notification Center, Apps, Quick Note | Start Screen Saver, Disable Screen Saver | Put Display to Sleep | Lock Screen | -. Closed by M3.
- U4. Whether holding modifier keys while the menu is open shows "⌘ Mission Control" style items in an `NSPopUpButton` (menu item alternates). Resolved 2026-10-31: the menu keeps Settings' alternates, and the closed title comes from the cell's own item, so it never depends on a hidden alternate being shown. Whether the alternates appear while a key is held is checked in gate M3.

## Approaches

- **A. Call the same two CoreDock functions as System Settings (chosen).** Live, no Dock restart, Settings shows the result at once, no permission prompt. Cost: private API, loaded with `dlsym` so a future macOS without it degrades to a notice instead of a crash.
- B. `defaults write com.apple.dock wvous-*` then `killall Dock`. Public-ish and well known, but restarts the Dock on every change (visible flicker, Dock state reset). Kept only as the re-plan path if U2 fails.
- C. System Events scripting (`expose preferences`). Needs an Automation permission prompt, is slower, and ends in the same Dock call. Rejected.
- D. Deep link to Settings only. Does not meet R4. Rejected.

## Behaviour

The Dock is the source of truth. The app keeps one thing of its own: the **snapshot**, the four corners as they were when the switch went off. It lives in the app's `UserDefaults` under `disabledSnapshot` and exists only while the switch is off.

- **Refresh** (at launch and every time the panel opens): read the Dock.
  - No snapshot: switch on, the pop-ups show what the Dock has.
  - Snapshot, and the Dock has no active corner: switch off, the pop-ups show the snapshot, dimmed to 30 percent.
  - Snapshot, but the Dock has an active corner (someone changed a corner in Settings while the app was off): Settings wins. Drop the snapshot, switch on, show the Dock. This holds even when the corner was set back to the very action the snapshot remembers.
  - Snapshot still marked in transition (a switch was interrupted, see below): active corners equal to the snapshot are this app's own partial writes, so the app stays off and switching on finishes the job. Only a corner that differs from the snapshot counts as a change in Settings.
- **Choose an item, switch on:** write that corner at once, read back, show what the Dock now has.
- **Choose an item, switch off:** update the snapshot only. Nothing reaches the Dock until the switch goes on. This is the EQ rule: everything stays usable while off, so corners can be set up before they are turned on.
- **Switch off:** read the Dock, save what was read as the snapshot marked in transition, write "-" to each active corner, then clear the mark. Corners that are already "-" are not written. Saving first means no failure, crash or kill in the middle can lose the corners.
- **Switch on:** write each snapshot corner that differs from the Dock, then drop the snapshot.
- **A write fails** (non-zero status, or the read-back still shows the old value 0.3 s after the call): undo the writes already made in that step, including the failed corner, read the Dock again, and show what is really there with a notice. If the undo worked, the app is back where the step started; if not, the snapshot stays marked in transition and nothing is lost.
- **The Dock stops answering in the middle of a step** (status -4956): stop at once without any undo calls, which would each block for up to 3 s, keep the snapshot marked, and show the Dock notice with the controls disabled.
- **The Dock does not answer, or the functions are missing:** show a notice, disable the controls, write nothing. Until the Dock has answered once, the panel shows the notice only: no switch and no pop-ups, since placeholder corners would read as real ones.
- Unknown action values (a future macOS) are shown as "Other (15)", kept as raw numbers, and survive off and on unchanged. The legacy value 0 shows as "-".
- Modifier keys work as in Settings: hold ⌘, ⌥, ⌃ or ⇧ while choosing; the title then reads "⌘ Mission Control". Modifiers survive off and on.

## UI

- Brandbook menu bar app: `MenuBarPanel` (section 6.1), no `NSPopover`, dark forced, red accent forced, `LSUIElement`.
- **Width 400 pt instead of the standard 340.** Two columns of pop-ups side by side need 176 pt each for the longest title (F11). At 340 a column is 150 pt and four titles would be cut. Brandbook 5.1 allows an exception when content demands it, as RetroPong's does. Every plain title fits the 178 pt column. A title with modifier keys can be up to 228 pt ("⌃⌥⇧⌘ Disable Screen Saver"), so the longer ones truncate with an ellipsis and the tooltip shows them whole; making the panel 500 pt wide for a rare case was not worth it.
- The closed pop-up shows the store's value through the cell's own item (`NSPopUpButtonCell.usesItemFromMenu = false`), so the menu itself stays exactly Settings' menu, alternates included, for every value.
- Header (brandbook 9.1, EQ layout): the app glyph at 16 pt, template, then "Imperator HotCorners" in `.headline`, a spacer, and the brand switch anchored trailing. On means corners are active.
- Content: a 2 by 2 grid, 12 pt between columns, 8 pt between rows, 16 pt padding. Top left pop-up at top left, and so on, so position says which corner it is. Each pop-up carries the Settings accessibility name and the full title as tooltip.
- Footer (brandbook 9.2, EQ layout): Open at Login switch, spacer, About, Quit.
- Notices (EQ's notice pattern, `.primary` and `.secondary` text, never red text):
  - API missing: "Hot corners can’t be changed here" / "This version of macOS doesn’t let other apps change hot corners. You can still set them in System Settings." / button "Open Desktop & Dock Settings".
  - Dock not answering: "Can’t read hot corners" / "The Dock didn’t answer. It usually comes back within a few seconds." / button "Try Again".
  - Write failed: "The top left corner didn’t change" (corner named) / "The Dock kept the old setting. Try again, or set it in System Settings." / button "Open Desktop & Dock Settings".
- States: there is no empty state (there are always four corners) and no loading state (a read takes 0.05 ms); the error states are the notices above.

## Icon

- Menu bar glyph (R7): Imperator WidgetClock's frame, drawn with its exact formula (16 by 12 pt at (1, 3) on an 18 pt canvas, stroke 1.125 pt, outer radius 1.7 pt, template), with the colon replaced by four corner marks.
  - Dot variant: dots 4 pt wide and as tall as the frame's border (Goran, 2026-10-31), with their outer corners 2 pt inside the frame's outer corners. At 18 pt: 4 by 1.125 pt at (3, 5), (11, 5), (3, 11.875), (11, 11.875). Mirror-symmetric. Like the border, a 1.125 pt dot has a soft edge row at 1x and 2x.
  - Stroke variant: a 45 degree line from the same inset points toward the centre, 1.75 pt in x and y, frame stroke width, round caps.
  - Both are rendered for review; Goran picks one (gate M5) and the other is deleted.
- The same glyph at 16 pt in the header (brandbook 9.1). At 16 pt the same formula gives a 14 by 11 frame at (1, 3), a 1 pt border, and 4 by 1 pt dots at x 3 and 9, y 5 and 11.
- App icon (Dock, Finder, About): the Imperator sigil on the dark rounded square in an app colour of Goran's choosing, made in Icon Composer and Imperator AppIcons like the other apps (gate M6). Not generated by the agent.

## Build and release

- SwiftPM, `swift-tools-version:6.4`, `platforms: [.macOS("26.0")]` (stamps minos 26.0 / sdk 26.0, brandbook default), `swiftLanguageMode(.v5)` last in every target.
- Universal binary (`--arch arm64 --arch x86_64`), signed with the stable `Imperator Dev` identity (keeps the login item registration across updates, as in the sibling apps).
- Bundle id `com.goranimperator.ImperatorHotCorners`, executable `ImperatorHotCorners`, copyright `Copyright © 2026 Goran Imperator. MIT License.`
- Makefile with the sibling targets: `build`, `test`, `icon`, `install`, `run`, `clean`, `dist`, `release`. `release` is only run on Goran's word, through the `imperator-release` skill.

## Calls I made (check these)

1. Approach A (private CoreDock functions) over B (defaults plus Dock restart).
2. Panel width 400 pt (brandbook exception) so no title is cut.
3. While off, choosing an item edits what comes back on, without touching the Dock (EQ rule).
4. Settings wins: a corner turned on in Settings while the app is off switches the app back on and drops the snapshot.
5. Modifier keys supported the way Settings does it, and preserved when untouched.
6. "R7 icon" read as the menu bar glyph (WidgetClock's frame with corner marks). The app icon stays the usual sigil, colour yours.
7. Minimum macOS 26 (brandbook default), universal binary.
8. No fallback writer: if the CoreDock functions disappear in a future macOS, the app shows a notice and links to Settings.

## Left to the builder

Internal naming beyond the interfaces in the plan, the exact wording of code comments, and the `--render-preview` background stand-in colour.
