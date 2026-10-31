# antislop Delivery Gate: Imperator HotCorners

Design Read: a macOS menu bar utility panel for one power user, in the Imperator brandbook language, dial ENERGY 1 / RHYTHM 1 / MOTION 1 (a system surface: calm, uniform, hover opacity as the only motion). Direction comes from `../imperator-apps-brandbook/BRANDBOOK.md`.

Status 2026-10-31: automated evidence recorded below. Items marked PENDING need Goran's live click-through (gate M2) or visual review (M4), because the controls change a real system setting and no session may click them on the real Dock.

## Block 1: Hard Gate

- R-02 PASS: `node scripts/check-dashes.mjs` prints `DASHES_OK` (scanner proves itself on a fixture first).
- R-03 PASS (n/a): fixed 400 pt macOS panel, no breakpoints.
- R-17, R-18, R-36, R-38 PASS: no statistics, testimonials, claims or invented content in the UI.
- R-23 PASS: the app logo is not generated. `Resources/AppIcon.png` is left for Goran (gate M6); until then the bundle shows the generic icon and `make build` says so.
- R-24 PASS: no navigation. The only links are "Open Desktop & Dock Settings" (`x-apple.systempreferences:com.apple.Desktop-Settings.extension`), the About website link and Quit.
- R-25 PENDING: text is `.primary` and `.secondary` system colors on the dark panel, never brand red text. Contrast not measured numerically; confirm in M4.
- R-26 PENDING: every control has a real action (pop-ups call `store.choose`, switch calls `store.setEnabled`, notice buttons open Settings or refresh, About, Quit). Click-through on the real backend belongs to M2.
- R-27 PASS: no empty or loading state exists (always four corners, a read takes 0.05 ms). Error states render: `build/preview/panel-dock-not-responding.png`, `panel-write-failed.png`, `panel-api-missing.png` (gate G8).
- R-28 PASS (n/a): no FAQ.
- R-32 PENDING: native `NSPopUpButton`, switches and buttons carry system focus handling; Escape closes the panel (`MenuBarPanel` key monitor). Confirm Tab order in M2.
- R-33 PASS: no patch scripts.
- R-34 PASS (n/a): dark is forced by the brandbook (14.1), there is no theme toggle.
- R-35 PENDING: built and launched checks pass (G1 to G11). The element-by-element click-through is Goran's M2 record. A debug build with `IMPERATOR_HOTCORNERS_FAKE=1` lets every state be clicked without touching real corners.
- R-37 PASS: direction loaded from the brandbook, dials declared above.

## Block 2: Purpose-Gate (reason written down)

- R-01 PASS: one accent, brand red `#A01818`, on the switch only, as the brandbook says. No gradients, no glow.
- R-04 PASS: the only icon is the app glyph, a screen frame with a mark in each corner: it shows what the app controls.
- R-06 PASS: system font, as the brandbook requires.
- R-07, R-08, R-09, R-10, R-12, R-13, R-14, R-19, R-22 PASS: none used. Motion is the 0.2 s hover opacity from the brandbook.

## Block 3: Liveliness

- Dials declared: yes (ENERGY 1 / RHYTHM 1 / MOTION 1), and the output matches: one panel, one grid, hover opacity only.
- Focal point: the four pop-ups. Whitespace: 16 pt padding, 12 and 8 pt grid gaps. One accent: the red switch.
- Identity motif: the corner-mark glyph, used in the menu bar and the header.

## Block 4: Craftsmanship

- C-1 PASS: each decision is written down in SPEC.md ("Calls I made").
- C-2 PENDING: see R-26.
- C-3 PASS: header, grid, footer are what the brandbook requires of a menu bar app and nothing else.
- C-4 PENDING: states render in previews; keyboard use confirmed in M2.
- C-5 PASS: no claims.
- R-05, R-11, R-15, R-16, R-20, R-21, R-29, R-30, R-31 PASS: no template layout, standard control radii, specific labels ("Open Desktop & Dock Settings", "Try Again"), no buzzwords, brand family look by design, palette is brand red plus system neutrals, no clone, reasons in SPEC.md.
