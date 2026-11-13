import AppKit
import HotCornersCore
import SwiftUI

/// `ImperatorHotCorners --render-preview <dir>` writes the panel in every
/// state, the glyph in both mark variants, and the menu order, and checks that
/// every plain action title fits its pop-up column. Nothing here touches the Dock.
@MainActor
enum PreviewRender {
    private static let goran = CornerLayout(dockActions: [2, 4, 11, 1], dockModifiers: [0, 0, 0, 0])

    private static func save(_ rep: NSBitmapImageRep, to url: URL) throws {
        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: url)
    }

    private static func bitmap(pixels: Int, points: CGFloat, draw: () -> Void) -> NSBitmapImageRep? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: rep)
        else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(pixels) / points, y: CGFloat(pixels) / points)
        context.imageInterpolation = .none
        draw()
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func render(_ store: HotCornerStore, update: UpdateChecker.Release? = nil) -> NSBitmapImageRep? {
        let view = PopoverContentView(store: store, dismissAction: {}, quitAction: {}, previewUpdate: update)
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        let backdrop = NSView(frame: host.frame)
        backdrop.wantsLayer = true
        // The panel's material does not render offscreen; this stands in for it.
        backdrop.layer?.backgroundColor = NSColor(white: 0.16, alpha: 1).cgColor
        backdrop.appearance = NSAppearance(named: .darkAqua)
        backdrop.addSubview(host)
        backdrop.layoutSubtreeIfNeeded()
        guard let rep = backdrop.bitmapImageRepForCachingDisplay(in: backdrop.bounds) else { return nil }
        backdrop.cacheDisplay(in: backdrop.bounds, to: rep)
        return rep
    }

    private static func store(_ layout: CornerLayout, configure: (InMemoryBackend, HotCornerStore) -> Void = { _, _ in }) -> HotCornerStore {
        let backend = InMemoryBackend(layout: layout)
        let store = HotCornerStore(backend: backend, defaults: InMemoryStorage())
        store.refresh()
        configure(backend, store)
        return store
    }

    static func run(directory: String) -> Int32 {
        _ = NSApplication.shared
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let dir = URL(fileURLWithPath: directory, isDirectory: true)
        var failures: [String] = []
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            print("FAIL cannot create \(directory)")
            return 1
        }

        let longest = CornerLayout(dockActions: [6, 3, 10, 12], dockModifiers: [0, 0, 0, 0])
        let modified = CornerLayout(
            dockActions: [2, 6, 11, 1],
            dockModifiers: [CornerModifiers.command.rawValue, CornerModifiers.command.rawValue,
                            CornerModifiers([.control, .shift]).rawValue, 0])
        let unread: HotCornerStore = {
            let backend = InMemoryBackend(layout: goran)
            backend.failReads = true
            let store = HotCornerStore(backend: backend, defaults: InMemoryStorage())
            store.refresh()
            return store
        }()
        let missing = HotCornerStore(backend: nil, defaults: InMemoryStorage())
        missing.refresh()
        let cases: [(String, HotCornerStore)] = [
            ("panel-on", store(goran)),
            ("panel-off", store(goran) { _, s in s.setEnabled(false) }),
            ("panel-modifiers", store(modified)),
            ("panel-longest", store(longest)),
            ("panel-unknown-action", store(CornerLayout(dockActions: [15, 4, 11, 1], dockModifiers: [0, 0, 0, 0]))),
            ("panel-dock-not-responding", store(goran) { b, s in b.failReads = true; s.refresh() }),
            ("panel-dock-never-answered", unread),
            ("panel-write-failed", store(goran) { b, s in
                b.failWrites = [.topLeft]
                s.choose(CornerSetting(action: .desktop, modifiers: []), for: .topLeft)
            }),
            ("panel-api-missing", missing),
        ]
        for (name, s) in cases {
            if let rep = render(s) {
                do { try save(rep, to: dir.appendingPathComponent("\(name).png")) }
                catch { failures.append("could not write \(name)") }
            } else {
                failures.append("could not render \(name)")
            }
        }

        // The update row, drawn from a sample release rather than the network.
        let sample = UpdateChecker.Release(version: "9.9.9",
                                           page: URL(string: "https://github.com/goranimperator/imperator-hotcorners/releases")!)
        if let rep = render(store(goran), update: sample) {
            do { try save(rep, to: dir.appendingPathComponent("panel-update-available.png")) }
            catch { failures.append("could not write panel-update-available") }
        } else {
            failures.append("could not render panel-update-available")
        }

        // The glyph, both marks, both sizes, at true 1x and 2x pixels, then blown
        // up 8 times without smoothing so a soft edge stays visible.
        for (markName, mark) in [("dot", StatusItemIcon.CornerMark.dot), ("stroke", .stroke)] {
            for size in [18, 16] {
                let icon = StatusItemIcon.make(size: CGFloat(size), mark: mark)
                for scale in [1, 2] {
                    for (tone, ink, paper) in [("light", NSColor.black, NSColor.white), ("dark", NSColor.white, NSColor.black)] {
                        let tinted = NSImage(size: icon.size, flipped: false) { rect in
                            icon.draw(in: rect)
                            ink.set()
                            rect.fill(using: .sourceAtop)
                            return true
                        }
                        let points = CGFloat(size)
                        guard let small = bitmap(pixels: size * scale, points: points, draw: {
                            paper.setFill()
                            NSRect(x: 0, y: 0, width: points, height: points).fill()
                            tinted.draw(in: NSRect(x: 0, y: 0, width: points, height: points))
                        }) else { continue }
                        let smallImage = NSImage(size: NSSize(width: points, height: points))
                        smallImage.addRepresentation(small)
                        guard let big = bitmap(pixels: size * scale * 8, points: points, draw: {
                            smallImage.draw(in: NSRect(x: 0, y: 0, width: points, height: points))
                        }) else { continue }
                        let file = "glyph-\(markName)-\(size)@\(scale)x-\(tone).png"
                        do { try save(big, to: dir.appendingPathComponent(file)) }
                        catch { failures.append("could not write \(file)") }
                    }
                }
            }
        }

        // The menu order, to compare with System Settings by eye.
        let order = CornerMenu.sections
            .map { $0.filter { !$0.isAlternate }.map(\.title).joined(separator: "\n") }
            .joined(separator: "\n---\n")
        do { try order.write(to: dir.appendingPathComponent("menu.txt"), atomically: true, encoding: .utf8) }
        catch { failures.append("could not write menu.txt") }

        // Every plain title has to fit one column of the real control. Titles
        // with modifier keys may truncate with an ellipsis (the tooltip shows
        // them whole); they are counted, not failed.
        func width(of title: String) -> CGFloat {
            let button = CornerPopUp.makeButton()
            (button.cell as? NSPopUpButtonCell)?.menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            return button.intrinsicContentSize.width
        }
        for action in HotCornerAction.menuSections.joined() where width(of: action.title) > CornerPopUp.columnWidth {
            failures.append("fit \(action.title) \(width(of: action.title))")
        }
        let modifiedTitles = CornerMenu.sections.joined().filter(\.isAlternate).map(\.title)
        let truncated = modifiedTitles.filter { width(of: $0) > CornerPopUp.columnWidth }.count
        print("fit: every plain title fits \(CornerPopUp.columnWidth) pt; \(truncated) of \(modifiedTitles.count) titles with modifier keys truncate")

        if failures.isEmpty {
            print("PREVIEW_OK")
            return 0
        }
        for failure in failures { print("FAIL \(failure)") }
        return 1
    }
}
