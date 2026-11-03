import AppKit
import SwiftUI

/// The menu bar panel, drawn by the app rather than by `NSPopover` (brandbook 6.1).
///
/// 18.25 pt rather than the Wi-Fi panel's measured 17.5, because
/// `NSVisualEffectView` blends its edge and the drawn corner comes out about
/// 0.75 pt tighter than the radius asked for. Circular, not continuous.
final class MenuBarPanel: NSPanel {
    static let cornerRadius: CGFloat = 18.25
    private static let menuBarGap: CGFloat = 2

    private let host: NSHostingView<AnyView>
    private let container = NSVisualEffectView()
    private var clickMonitor: Any?
    private var appClickMonitor: Any?
    private var keyMonitor: Any?
    /// The menu bar press monitor, registered for the panel's whole life.
    private var statusPressMonitor: Any?
    /// Whether the panel was up when the current click on the status item
    /// started, so the button's action knows it is a close and not an open.
    private var panelWasOpenAtStatusPress = false
    private weak var anchor: NSStatusBarButton?
    private var resignObserver: NSObjectProtocol?

    /// Called when the panel closes itself, so the owner can keep the status
    /// item's pressed state honest.
    var onClose: (() -> Void)?

    /// The height the panel opens at, when the app computes it itself.
    var contentHeight: (() -> CGFloat)?

    /// Asked before an outside click closes the panel.
    var shouldCloseOnOutsideClick: () -> Bool = { true }

    init<Content: View>(content: Content, width: CGFloat) {
        host = NSHostingView(rootView: AnyView(content))
        super.init(contentRect: NSRect(x: 0, y: 0, width: width, height: 100),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)

        // isFloatingPanel sets the level itself, so it goes first: after
        // .popUpMenu it would drop the panel back to the floating level, under
        // the Dock and the menu bar, and the level set here would be a no-op.
        isFloatingPanel = true
        level = .popUpMenu
        // Not hidesOnDeactivate: that hides the panel without close(), leaving the
        // Escape monitor installed. The panel closes itself on deactivation instead.
        hidesOnDeactivate = false
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isVisible else { return }
                self.close()
            }
        }
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = false

        container.material = .popover
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = Self.cornerRadius
        container.layer?.cornerCurve = .circular
        container.layer?.masksToBounds = true

        host.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        contentView = container

        // Registered once, for the panel's whole life, and never beside the
        // monitors below: those are removed by `close()`, and a press that takes
        // the panel down has to be seen before it does. Set at every menu bar
        // press, so a record left by an earlier click cannot outlive the click
        // that follows it: a record that did made the panel take two clicks to
        // open.
        statusPressMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self, Self.isMenuBarPress(event) else { return event }
            self.panelWasOpenAtStatusPress = self.isVisible
            return event
        }
    }

    var isShown: Bool { isVisible }

    func show(from button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        anchor = button

        panelWasOpenAtStatusPress = false
        host.layoutSubtreeIfNeeded()
        let height = contentHeight?() ?? host.fittingSize.height
        setContentSize(NSSize(width: frame.width, height: height))

        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        var x = buttonFrame.midX - frame.width / 2
        // Keep the panel on screen when the item sits near an edge, the way the
        // system's own panels slide rather than hang off.
        if let visible = screen?.visibleFrame {
            x = min(max(x, visible.minX + 8), visible.maxX - frame.width - 8)
        }
        setFrameTopLeftPoint(NSPoint(x: x, y: buttonFrame.minY - Self.menuBarGap))

        orderFrontRegardless()
        startMonitoring()
    }

    /// Re-measures the content and keeps the top edge where it is, for a notice
    /// that appears or goes while the panel is open.
    func refit() {
        guard isVisible else { return }
        let top = frame.maxY
        host.layoutSubtreeIfNeeded()
        let height = contentHeight?() ?? host.fittingSize.height
        setContentSize(NSSize(width: frame.width, height: height))
        setFrameTopLeftPoint(NSPoint(x: frame.minX, y: top))
    }

    /// An override, so every `close()` in the app lands here and the monitors
    /// go with the panel.
    override func close() {
        // A click on the status item can close the panel before the button's
        // action arrives. That is recorded at the press itself, by the monitor in
        // init. Only a press is recorded here, never the mouse up the action
        // arrives on: re-arming there left the record set after the click that
        // closed the panel, so the next click read as a close and did nothing.
        // Decided from the menu bar strip rather than the item's own rect: a
        // status item's button can be rebuilt by AppKit, and a rect read from a
        // stale one would never match.
        if isMenuBarPress(NSApp.currentEvent) { panelWasOpenAtStatusPress = true }
        stopMonitoring()
        super.close()
        onClose?()
    }

    /// Whether a click on the status item closes the panel.
    ///
    /// True when the panel is up, or was up when the press landed and has
    /// closed itself since: a press can close the panel before the button's
    /// action arrives, through the outside click monitors or a resign, and an
    /// action that read `isShown` alone would reopen what the press just closed.
    func statusClickShouldClose() -> Bool {
        let shouldClose = isVisible || panelWasOpenAtStatusPress
        panelWasOpenAtStatusPress = false
        return shouldClose
    }

    private func startMonitoring() {
        stopMonitoring()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return }
            guard self.shouldCloseOnOutsideClick() else { return }
            // The event knows where it landed; a global event from another app
            // has no window, and then the pointer is the same answer.
            let pointer = Self.screenPoint(of: event)
            // A click in the menu bar is not a click outside: on the status item
            // it is the toggle, and closing here races the button's action, which
            // then reopens what it just closed. Anywhere else in the bar the app
            // resigns or the other item takes over, and that closes the panel.
            if Self.isMenuBarPoint(pointer) { return }
            // Decide outside from where the pointer is, not from which monitor
            // saw the event: the first click into an inactive accessory app
            // reaches a global monitor too.
            if self.frame.contains(pointer) { return }
            self.close()
        }
        // A click in another window of this app (About, say) is a click outside
        // too. The global monitor never sees those. Menus sit at the pop-up menu
        // level or above, so a pop-up's own menu never counts, and the status
        // item's click is left to its toggle.
        appClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let window = event.window else { return event }
            // Where the click landed decides, not which window it arrived in: a
            // click on the status item can arrive in a window the anchor check
            // would not recognize, and closing on it would race the toggle.
            let point = Self.screenPoint(of: event)
            if window === self || self.frame.contains(point) { return event }
            if Self.isMenuBarPoint(point) { return event }
            guard window.level.rawValue < NSWindow.Level.popUpMenu.rawValue else { return event }
            self.close()
            return event
        }
        // Escape belongs to the panel only while the panel has it; About keeps its own.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, let self, event.window === self else { return event }   // Escape
            self.close()
            return nil
        }
    }

    private func stopMonitoring() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let appClickMonitor { NSEvent.removeMonitor(appClickMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        clickMonitor = nil
        appClickMonitor = nil
        keyMonitor = nil
    }

    /// Whether a screen point is in a screen's menu bar strip. The status item
    /// lives there, so a click there is the toggle or another item's, never a
    /// click outside this panel.
    private static func isMenuBarPoint(_ point: NSPoint) -> Bool {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) else { return false }
        return point.y > screen.frame.maxY - NSStatusBar.system.thickness
    }

    private static func screenPoint(of event: NSEvent) -> NSPoint {
        event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
    }

    /// Down only: a press is the click's own event, the up is the button's action
    /// arriving, and reading that as a press is what re-armed the record.
    private static func isMenuBarPress(_ event: NSEvent?) -> Bool {
        guard let event, event.type == .leftMouseDown || event.type == .rightMouseDown else { return false }
        return isMenuBarPoint(screenPoint(of: event))
    }

    private func isMenuBarPress(_ event: NSEvent?) -> Bool { Self.isMenuBarPress(event) }

    // A borderless panel refuses key status by default, which leaves the
    // SwiftUI content unable to take Escape or drive its controls.
    override var canBecomeKey: Bool { true }

    deinit {
        stopMonitoring()
        if let statusPressMonitor { NSEvent.removeMonitor(statusPressMonitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
    }
}
