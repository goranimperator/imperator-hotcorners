import AppKit
import HotCornersCore
import SwiftUI

/// `ImperatorHotCorners --panel-check` opens the real panel on an in-memory
/// Dock and drives it: the window level the brandbook asks for, a click on the
/// switch, a click inside the panel, Escape, and the height refit that a notice
/// needs. Nothing here touches the real Dock or the real corners.
@MainActor
enum PanelCheck {
    private static var failures: [String] = []

    private static func expect(_ condition: Bool, _ message: String) {
        if !condition { failures.append(message) }
    }

    private static func click(_ panel: NSPanel, at point: NSPoint) {
        let now = ProcessInfo.processInfo.systemUptime
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            guard let event = NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: now,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0,
                clickCount: 1, pressure: 1) else { continue }
            panel.sendEvent(event)
        }
    }

    /// A press in the menu bar, where the status item lives, the way a real
    /// click arrives: through the app, so the panel's own local monitors see it.
    /// Where the status item sits: in the menu bar strip.
    private static var menuBarPoint: NSPoint? {
        guard let screen = NSScreen.main else { return nil }
        return NSPoint(x: screen.frame.midX, y: screen.frame.maxY - 6)
    }

    private static func pressMenuBar() {
        guard let point = menuBarPoint else { return }
        press(at: point)
    }

    /// A press at a screen point, delivered through an ordinary window of the app.
    /// One window for the whole check, kept alive: a press whose window has gone
    /// reports no location, and the panel would then judge it by the real pointer.
    private static var probeWindow: NSWindow?

    private static func window() -> NSWindow {
        if let probeWindow { return probeWindow }
        let window = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: 40, height: 40),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.orderFrontRegardless()
        probeWindow = window
        return window
    }

    private static func mouseEvent(_ type: NSEvent.EventType, at screenPoint: NSPoint) -> NSEvent? {
        let window = window()
        let point = window.convertPoint(fromScreen: screenPoint)
        return NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0,
            clickCount: 1, pressure: 1)
    }

    /// Taken through the queue, not sent: `NSApp.currentEvent` is set when the
    /// event comes off the queue, and the panel reads it to see that a close is
    /// a click on the status item.
    private static func post(_ event: NSEvent) {
        NSApp.postEvent(event, atStart: false)
        while let next = NSApp.nextEvent(matching: .any,
                                        until: Date(timeIntervalSinceNow: 0.05),
                                        inMode: .default, dequeue: true) {
            NSApp.sendEvent(next)
        }
    }

    private static func press(at screenPoint: NSPoint) {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            guard let event = mouseEvent(type, at: screenPoint) else { continue }
            post(event)
        }
    }

    /// Closes the panel the way the status item's action does: while a menu bar
    /// mouse up is the current event.
    private static func closeOnMenuBarUp(_ panel: MenuBarPanel) {
        guard let point = menuBarPoint, let up = mouseEvent(.leftMouseUp, at: point) else { return }
        let closer = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak panel] _ in
            panel?.close()
            return nil
        }
        post(up)
        if let closer { NSEvent.removeMonitor(closer) }
    }

    private static func escape(_ panel: NSPanel) {
        guard let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber, context: nil, characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53) else { return }
        NSApp.sendEvent(event)
    }

    /// The switch's row: 12 pt under a 2 by 2 grid of 178 pt columns, which puts
    /// its centre about 137 pt below the panel's top edge.
    private static let switchCentre: CGFloat = 137

    static func run() -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let backend = InMemoryBackend(
            layout: CornerLayout(dockActions: [2, 4, 11, 1], dockModifiers: [0, 0, 0, 0]))
        let store = HotCornerStore(backend: backend, defaults: InMemoryStorage())
        let panel = MenuBarPanel(
            content: PopoverContentView(store: store, dismissAction: {}, quitAction: {}),
            width: PopoverContentView.width)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else {
            print("FAIL no status bar button")
            return 1
        }
        store.refresh()

        // isFloatingPanel sets the level itself, so it must be set before the
        // level; in the other order .popUpMenu is silently replaced by .floating
        // and the panel sits under the Dock and the menu bar.
        expect(panel.level == .popUpMenu, "window level is \(panel.level.rawValue), not popUpMenu")
        expect(panel.canBecomeKey, "the panel cannot become key, so its controls cannot be driven")
        expect(panel.isReleasedWhenClosed == false, "the panel is released when closed, so it cannot reopen")

        panel.show(from: button)
        expect(panel.isVisible, "the panel did not open")
        let height = panel.frame.height
        expect(height > 0, "the panel opened at no height")

        // Watching the corners go off: the click has to land on the switch even
        // though the panel was not key when the pointer went down.
        click(panel, at: NSPoint(x: 160, y: height - switchCentre))
        expect(!store.isEnabled, "a click on the switch did not disable the corners")
        expect(panel.isVisible, "a click on the switch closed the panel")

        click(panel, at: NSPoint(x: 160, y: height - switchCentre))
        expect(store.isEnabled, "a second click on the switch did not bring the corners back")
        expect(backend.layout.hasActiveCorner, "the corners stayed off in the Dock")

        click(panel, at: NSPoint(x: 30, y: height - 45))
        expect(panel.isVisible, "a click inside the panel closed it")

        escape(panel)
        expect(!panel.isVisible, "Escape did not close the panel")

        panel.show(from: button)
        expect(panel.isVisible, "the panel did not open a second time")

        // A write that fails while the panel is open grows a notice, and the
        // panel is refit to it; without that the notice is cut off.
        backend.failWrites = [.topLeft]
        store.choose(CornerSetting(action: .desktop, modifiers: []), for: .topLeft)
        expect(store.problem == .writeFailed(.topLeft), "the failed write left no notice")
        panel.refit()
        expect(panel.frame.height > height, "the panel did not grow for the notice")
        panel.close()

        // A click on the status item is the toggle: it must leave the panel to
        // the button's action, not close it as an outside click. The menu bar is
        // recognized by where the press landed, so it holds even when the item's
        // own button is not the object the panel was shown from.
        panel.show(from: button)
        pressMenuBar()
        // Whether the press leaves the panel up or takes it down (a resign can),
        // the click has to be read as the toggle. Reading it as an open is the
        // bug this covers.
        expect(panel.statusClickShouldClose(),
               "a press on the status item is not read as the toggle, so the click reopens it")

        // And if some closer does take the panel down during that press, the
        // action has to read it as a close.
        let closer = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak panel] _ in
            panel?.close()
            return nil
        }
        panel.show(from: button)
        pressMenuBar()
        if let closer { NSEvent.removeMonitor(closer) }
        expect(!panel.isVisible, "the closer did not take the panel down")
        expect(panel.statusClickShouldClose(),
               "a close during the status click is read as an open, so the click reopens it")
        expect(!panel.statusClickShouldClose(), "the press state was not consumed")

        // The click that closes the panel is a press and then the button's action
        // on the mouse up. The action's own close must not leave the record set:
        // a record left behind is the next click read as a close, which is the
        // "click twice to open" bug.
        panel.show(from: button)
        pressMenuBar()
        expect(panel.statusClickShouldClose(), "an open panel is not read as a close")
        closeOnMenuBarUp(panel)
        expect(!panel.isVisible, "the action's close did not take the panel down")
        pressMenuBar()
        expect(!panel.statusClickShouldClose(),
               "the click after a close is read as another close, so it takes two clicks to open")

        // A click below the menu bar is still a click outside, and closes, and is
        // not the toggle.
        panel.show(from: button)
        press(at: NSPoint(x: 200, y: 200))
        expect(!panel.isVisible, "a click outside the panel did not close it")
        expect(!panel.statusClickShouldClose(), "an outside click reads as the toggle")

        if failures.isEmpty {
            print("PANEL_CHECK_OK")
            return 0
        }
        for failure in failures { print("FAIL \(failure)") }
        return 1
    }
}
