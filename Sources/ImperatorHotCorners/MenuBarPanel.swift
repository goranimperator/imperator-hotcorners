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
    private weak var anchor: NSStatusBarButton?

    /// Called when the panel closes itself, so the owner can keep the status
    /// item's pressed state honest.
    var onClose: (() -> Void)?

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
        // Brandbook 6.1: the panel hides with the app, so it never sits over
        // another one. Not a close on didResignActive instead: macOS hands an
        // accessory app's activation back a few seconds after the panel opens
        // (measured here), so a close on that resign took the panel down under a
        // still pointer, and the next click reopened it instead of closing it.
        hidesOnDeactivate = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = false
        // Brandbook 6.1: no animation. macOS puts its own menu bar panels up and
        // takes them down instantly, and a fade is what marks an app as not part
        // of the system.
        animationBehavior = .none

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
    }

    var isShown: Bool { isVisible }

    func show(from button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        anchor = button

        host.layoutSubtreeIfNeeded()
        let height = host.fittingSize.height
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
        let height = host.fittingSize.height
        setContentSize(NSSize(width: frame.width, height: height))
        setFrameTopLeftPoint(NSPoint(x: frame.minX, y: top))
    }

    /// An override, so every `close()` in the app lands here and the monitors
    /// go with the panel.
    override func close() {
        stopMonitoring()
        super.close()
        onClose?()
    }

    private func startMonitoring() {
        stopMonitoring()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return }
            // The event knows where it landed; a global event from another app
            // has no window, and then the pointer is the same answer.
            let pointer = Self.screenPoint(of: event)
            // The item the panel was shown from is the toggle. Closing on its
            // click here races the button's action, which then reopens what it
            // just closed.
            if self.isOnAnchorItem(pointer) { return }
            // With no window for that item its click cannot be told from another
            // item's, and closing on it would race the toggle the same way.
            if self.anchor?.window == nil, Self.isMenuBarPoint(pointer) { return }
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

    /// Whether a screen point lands on the status item the panel was shown from.
    /// Read from the item's window at click time, so a button AppKit rebuilt
    /// still matches.
    private func isOnAnchorItem(_ point: NSPoint) -> Bool {
        guard let window = anchor?.window else { return false }
        return window.frame.contains(point)
    }

    /// Whether a screen point is in a screen's menu bar strip. The status item
    /// lives there, so a click there is the toggle or another item's, never a
    /// click outside this panel.
    static func isMenuBarPoint(_ point: NSPoint) -> Bool {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) else { return false }
        return point.y > screen.frame.maxY - menuBarHeight(of: screen)
    }

    /// The menu bar's real height on a screen. `NSStatusBar.thickness` is the
    /// short bar; on a display with a notch the bar is as tall as the notch, and
    /// a click on the lower part of an item would otherwise count as outside.
    static func menuBarHeight(of screen: NSScreen) -> CGFloat {
        max(NSStatusBar.system.thickness,
            screen.frame.maxY - screen.visibleFrame.maxY,
            screen.safeAreaInsets.top)
    }

    private static func screenPoint(of event: NSEvent) -> NSPoint {
        event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
    }

    // A borderless panel refuses key status by default, which leaves the
    // SwiftUI content unable to take Escape or drive its controls.
    override var canBecomeKey: Bool { true }

    deinit {
        stopMonitoring()
    }
}
