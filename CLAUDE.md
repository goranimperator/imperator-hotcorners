# CLAUDE.md

Imperator HotCorners: a menu bar app that shows the four macOS hot corners as pop-up buttons and a "Disable HotCorners" switch under them that turns all of them off and back on. Design direction is `../imperator-apps-brandbook/BRANDBOOK.md`. Spec and gates: `SPEC.md`, `GATES.md`. The original build plan and the antislop report are kept locally in `.notes/` (gitignored).

## Commands

```bash
swift test
make build
.build/debug/ImperatorHotCorners --dock-check
.build/debug/ImperatorHotCorners --icon-check
.build/debug/ImperatorHotCorners --panel-check
.build/debug/ImperatorHotCorners --render-preview build/preview
node ~/.claude/skills/unlazy/scripts/gate-check.mjs --status GATES.md
```

`IMPERATOR_HOTCORNERS_FAKE=1` on a debug build swaps the Dock for a fake with an in-memory snapshot, so every state can be clicked without touching real corners or the real defaults. `IMPERATOR_HOTCORNERS_FAKE_FAIL` takes `reads` or `tl,tr,bl,br`.

## Layout

- `Sources/HotCornersCore`: model, store (state rules and the off-state snapshot), menu model, Dock backend.
- `Sources/ImperatorHotCorners`: AppKit and SwiftUI shell, plus the `--*-check` gates.
- `scripts/calibrate-dock.swift`: supervised calibration of the Dock setter.

## Dock facts (details in SPEC.md)

- System Settings reads and writes corners with `CoreDockGetExposeCornerActionsWithModifiers(int32 actions[4], int32 modifiers[4])` and `CoreDockSetExposeCornerActionWithModifier(action, corner, modifiers)`, order top left, top right, bottom left, bottom right.
- Modifiers are `NSEvent.ModifierFlags` bits, masked with `0x1E0000`.
- Calibrated by Goran 2026-10-31 (macOS 27.2, 26B123, gate M1): argument order (action, corner, modifiers), corner codes top left 0, top right 1, bottom left 2, bottom right 3.

## Decisions recorded

- Pop-up title (SPEC U4): the menu always holds Settings' items and modifier alternates; the closed button shows the store's value through `NSPopUpButtonCell.menuItem` with `usesItemFromMenu = false`.
- The disable switch is not in the header (2026-11-03). It sits on its own row under the four pop-ups, reads "Disable HotCorners", and is on when every corner is off, which is the inverse of `store.isEnabled` and of EQ's header switch. The header holds no controls.
- `togglePanel` decides from `panel.isShown`, as brandbook 18.1 does, and nothing may close the panel on the click itself (2026-11-04). Three rules keep that true: a click in the menu bar strip is never an outside click, and neither is a click on the item the panel was shown from; the panel hides with the app (`hidesOnDeactivate`), it does not close on `didResignActive`; and there is no press-time record. An earlier build closed on that resign, and macOS hands an accessory app's activation back a few seconds after the panel opens, so the panel took itself down under a still pointer and the next click reopened it instead of closing it. `--panel-check` (gate G13) posts the resign and fails if the panel goes away, which is the slow-second-click regression.
- `isFloatingPanel` sets the window level, so it is set before `level = .popUpMenu` in `MenuBarPanel` (2026-11-03). In the other order the level silently becomes `.floating` (3) and the panel sits under the Dock and the menu bar. `--panel-check` (gate G13) fails on it.
- A switch saves its snapshot marked in transition before the first Dock write. A record still marked after a failure is how `refresh()` tells this app's partial writes from changes made in System Settings.

- Update check (2026-11-13, from the shared Imperator update-checker spec, same as EQ): `UpdateChecker.swift` makes the app's only network request, one `GET` a day to `api.github.com/repos/goranimperator/imperator-hotcorners/releases/latest`, sending only `Imperator-HotCorners/<version>` as the User-Agent. It needs the repo to stay public. On by default with a footer switch and Check Now; the notification permission is asked only when there is an update; one notification per version; links open only for https://github.com. Do not remove it as unrequested network code, and do not widen what it sends.

## Rules

- After every change, run `make install` yourself so the new build is live in /Applications. Do not ask Goran to deploy.
- Never call the Dock setter against the real Dock from a session, and never click the app's controls on the real backend. Both change a system setting. Tests use `InMemoryBackend`.
- Never `git commit` or `git push` unless Goran says so in that message.
- English only in files, comments and UI. No em dashes or en dashes anywhere.
- Never use bare `Color.accentColor`; always `AppColors.brand`.
