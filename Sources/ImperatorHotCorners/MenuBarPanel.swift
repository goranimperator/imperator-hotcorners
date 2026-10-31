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

        level = .popUpMenu
        isFloatingPanel = true
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
    }

    var isShown: Bool { isVisible }

    func show(from button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        anchor = button

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
        stopMonitoring()
        super.close()
        onClose?()
    }

    private func startMonitoring() {
        stopMonitoring()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self else { return }
            guard self.shouldCloseOnOutsideClick() else { return }
            let pointer = NSEvent.mouseLocation
            // The status item's own click is the toggle. Closing here too races
            // the button's action, which then reopens what it just closed.
            if let window = self.anchor?.window, window.frame.contains(pointer) { return }
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
            guard let self, let window = event.window, window !== self, window !== self.anchor?.window,
                  window.level.rawValue < NSWindow.Level.popUpMenu.rawValue else { return event }
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

    // A borderless panel refuses key status by default, which leaves the
    // SwiftUI content unable to take Escape or drive its controls.
    override var canBecomeKey: Bool { true }

    deinit {
        stopMonitoring()
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
    }
}
