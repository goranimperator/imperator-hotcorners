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

    /// A press in the menu bar strip, where the status item lives. Not read from
    /// the item's own rect: a status item in a check run is never laid out in the
    /// strip (its rect sits at the window's origin), so the rule that protects the
    /// toggle is measured where it applies, in the strip itself.
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

    /// Taken through the queue, not sent: the app's own monitors only run for
    /// events that come off the queue.
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
        expect(panel.animationBehavior == .none,
               "the panel animates when it opens; brandbook 6.1 puts its panels up instantly")

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

        // Brandbook 18.1: the status item's action decides from `isShown`, which
        // only holds while nothing closes the panel on the click itself. Its own
        // click is the toggle, never an outside click.
        panel.show(from: button)
        pressMenuBar()
        expect(panel.isVisible,
               "a click in the menu bar closed the panel before its action, so it cannot toggle")
        expect(panel.isShown, "the open panel does not report itself as shown, so its action would reopen it")
        // The lowest row of the strip too: on a display with a notch the bar is
        // taller than NSStatusBar.thickness.
        if let screen = NSScreen.main {
            let low = NSPoint(x: screen.frame.midX, y: screen.frame.maxY - MenuBarPanel.menuBarHeight(of: screen) + 1)
            expect(MenuBarPanel.isMenuBarPoint(low), "the bottom row of the menu bar counts as outside the strip")
            press(at: low)
            expect(panel.isVisible, "a click on the bottom row of the menu bar closed the panel")
        }

        // The action's close leaves nothing behind: the click after it opens.
        panel.close()
        expect(!panel.isShown,
               "a closed panel still reports itself as shown, so the next click closes instead of opens")

        // A guard against bringing the resign observer back. Activation is not the panel's life. macOS hands an accessory app's
        // activation back a few seconds after the panel opens, and a panel that
        // closed on that resign came down under a still pointer: the click after
        // the pause reopened it instead of closing it.
        panel.show(from: button)
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        expect(panel.isVisible,
               "the panel closed itself when the app lost activation, so a slow second click reopens it")
        // And the app losing focus is handled by the window, not by a stray
        // panel left over another app.
        expect(panel.hidesOnDeactivate, "the panel would stay on screen over another app")
        panel.close()

        // A click below the menu bar is still a click outside, and closes.
        panel.show(from: button)
        press(at: NSPoint(x: 200, y: 200))
        expect(!panel.isVisible, "a click outside the panel did not close it")

        if failures.isEmpty {
            print("PANEL_CHECK_OK")
            return 0
        }
        for failure in failures { print("FAIL \(failure)") }
        return 1
    }
}
