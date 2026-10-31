# CLAUDE.md

Imperator HotCorners: a menu bar app that shows the four macOS hot corners as pop-up buttons and has a header switch that turns all of them off and on. Design direction is `../imperator-apps-brandbook/BRANDBOOK.md`. Spec, plan and gates: `SPEC.md`, `PLAN.md`, `GATES.md`.

## Commands

```bash
swift test
make build
.build/debug/ImperatorHotCorners --dock-check
.build/debug/ImperatorHotCorners --icon-check
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
- A switch saves its snapshot marked in transition before the first Dock write. A record still marked after a failure is how `refresh()` tells this app's partial writes from changes made in System Settings.

## Rules

- After every change, run `make install` yourself so the new build is live in /Applications. Do not ask Goran to deploy.
- Never call the Dock setter against the real Dock from a session, and never click the app's controls on the real backend. Both change a system setting. Tests use `InMemoryBackend`.
- Never `git commit` or `git push` unless Goran says so in that message.
- English only in files, comments and UI. No em dashes or en dashes anywhere.
- Never use bare `Color.accentColor`; always `AppColors.brand`.
