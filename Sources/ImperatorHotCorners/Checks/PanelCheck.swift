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
    private static func pressMenuBar() {
        guard let screen = NSScreen.main else { return }
        press(at: NSPoint(x: screen.frame.midX, y: screen.frame.maxY - 6))
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

    private static func press(at screenPoint: NSPoint) {
        let window = window()
        let point = window.convertPoint(fromScreen: screenPoint)
        let now = ProcessInfo.processInfo.systemUptime
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            guard let event = NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: now,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                clickCount: 1, pressure: 1) else { continue }
            // Taken through the queue, not sent: `NSApp.currentEvent` is set
            // when the event comes off the queue, and the panel reads it to see
            // that this close is a click on the status item.
            NSApp.postEvent(event, atStart: false)
            while let next = NSApp.nextEvent(matching: .any,
                                            until: Date(timeIntervalSinceNow: 0.05),
                                            inMode: .default, dequeue: true) {
                NSApp.sendEvent(next)
            }
        }
    }

    /// The mouse up the status item's action arrives with.
    private static func actionEvent() -> NSEvent? {
        guard let screen = NSScreen.main else { return nil }
        return mouseUp(at: NSPoint(x: screen.frame.midX, y: screen.frame.maxY - 6))
    }

    private static func mouseUp(at screenPoint: NSPoint) -> NSEvent? {
        let window = window()
        let point = window.convertPoint(fromScreen: screenPoint)
        return NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [],
                                  timestamp: ProcessInfo.processInfo.systemUptime,
                                  windowNumber: window.windowNumber, context: nil,
                                  eventNumber: 0, clickCount: 1, pressure: 1)
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
        expect(panel.statusClickShouldClose(for: actionEvent()),
               "a press on the status item is not read as the toggle, so the click reopens it")

        // And if some closer does take the panel down during that press, the
        // action has to read it as a close. The record is made inside close(),
        // so it cannot depend on which local monitor AppKit calls first.
        let closer = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak panel] _ in
            panel?.close()
            return nil
        }
        panel.show(from: button)
        pressMenuBar()
        if let closer { NSEvent.removeMonitor(closer) }
        expect(!panel.isVisible, "the closer did not take the panel down")
        expect(panel.statusClickShouldClose(for: actionEvent()),
               "a close during the status click is read as an open, so the click reopens it")
        expect(!panel.statusClickShouldClose(for: actionEvent()), "the press state was not consumed")

        // A close with no event of its own, as a resign gives, followed by the
        // button's action on the menu bar: still the same click.
        panel.show(from: button)
        panel.close()
        expect(panel.statusClickShouldClose(for: actionEvent()),
               "a close just before the click reopens the panel")
        expect(!panel.statusClickShouldClose(for: actionEvent()), "the close state was not consumed")
        expect(!panel.statusClickShouldClose(for: mouseUp(at: NSPoint(x: 200, y: 200))),
               "a click below the menu bar read as the toggle")

        // A click below the menu bar is still a click outside, and closes.
        panel.show(from: button)
        press(at: NSPoint(x: 200, y: 200))
        expect(!panel.isVisible, "a click outside the panel did not close it")
        expect(!panel.statusClickShouldClose(for: mouseUp(at: NSPoint(x: 200, y: 200))),
               "an outside click reads as the toggle")

        panel.show(from: button)
        panel.close()
        Thread.sleep(forTimeInterval: 0.5)
        expect(!panel.statusClickShouldClose(for: actionEvent()),
               "a later click with the panel down does not read as a close")

        if failures.isEmpty {
            print("PANEL_CHECK_OK")
            return 0
        }
        for failure in failures { print("FAIL \(failure)") }
        return 1
    }
}
