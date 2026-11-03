import AppKit
import Combine
import HotCornersCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: MenuBarPanel!
    private var store: HotCornerStore!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        UserDefaults.standard.set(0, forKey: "AppleAccentColor")
        ProcessInfo.processInfo.setValue("Imperator HotCorners", forKey: "processName")

        store = HotCornerStore(backend: CoreDockBackend.system())
        #if DEBUG
        // The fake keeps its snapshot in memory, so a fake run can never leave
        // corners behind for a later run on the real Dock.
        if let fake = makeDebugBackend() { store = HotCornerStore(backend: fake, defaults: InMemoryStorage()) }
        #endif

        // The menu bar icon first: a Dock that does not answer can block a read
        // for 3 s. The first read happens when the panel opens.
        setupStatusItem()
        setupPanel()

        store.$problem
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.panel.refit() }
            .store(in: &cancellables)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.image = StatusItemIcon.make()
        button.toolTip = "Imperator HotCorners"
        button.setAccessibilityLabel("Imperator HotCorners")
        button.action = #selector(togglePanel)
        button.target = self
    }

    private func setupPanel() {
        panel = MenuBarPanel(
            content: PopoverContentView(
                store: store,
                dismissAction: { [weak self] in self?.closePanel() },
                quitAction: { NSApplication.shared.terminate(nil) }),
            width: PopoverContentView.width)
        panel.onClose = { [weak self] in self?.statusItem.button?.highlight(false) }
    }

    @objc private func togglePanel() {
        // Not `panel.isShown`: the press itself can close the panel, and the
        // click would then reopen it instead of closing it.
        if panel.statusClickShouldClose(for: NSApp.currentEvent) { closePanel() } else { showPanel() }
    }

    private func showPanel() {
        guard let button = statusItem.button else { return }
        // Settings may have changed since the panel was last open.
        store.refresh()
        panel.show(from: button)
        NSApp.activate(ignoringOtherApps: true)
        // Pressed while the panel is open, like the system's own menu bar items.
        // After the click's own tracking, which would otherwise clear it. The
        // panel can already be closed again by then, and a highlight set after
        // that would stay on with nothing open.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel.isShown else { return }
            button.highlight(true)
        }
    }

    private func closePanel() {
        guard panel.isShown else { return }
        panel.close()
    }
}
