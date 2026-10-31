import AppKit
import HotCornersCore
import SwiftUI

/// One corner's pop-up: a native `NSPopUpButton` holding System Settings' menu,
/// modifier alternates included. The menu never changes; the closed button
/// shows the store's value through the cell's own item.
struct CornerPopUp: NSViewRepresentable {
    static let columnWidth: CGFloat =
        (PopoverContentView.width - 2 * PopoverContentView.padding - PopoverContentView.columnSpacing) / 2

    let corner: Corner
    let setting: CornerSetting
    let isEnabled: Bool
    let onChoose: (CornerSetting) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// The button as the panel uses it. The fit check in `--render-preview`
    /// measures this exact control.
    static func makeButton() -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.controlSize = .regular
        // The closed button draws the cell's own item, set from the store, not
        // the menu's selected item: a value with a modifier key lives in a hidden
        // alternate, which a closed pop-up cannot show.
        (button.cell as? NSPopUpButtonCell)?.usesItemFromMenu = false
        // The menu holds modifier alternates far wider than any shown title, and
        // an NSPopUpButton sizes itself to its widest item. The column decides.
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return button
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = Self.makeButton()
        button.setAccessibilityLabel(corner.settingsName)
        let menu = NSMenu()
        menu.autoenablesItems = false
        for (index, section) in CornerMenu.sections.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            for entry in section {
                let item = NSMenuItem(title: entry.title, action: #selector(Coordinator.chosen(_:)), keyEquivalent: "")
                item.target = context.coordinator
                item.representedObject = entry.setting
                // AppKit's default mask is command, which would make the command
                // alternate indistinguishable from its own base item.
                item.keyEquivalentModifierMask = entry.isAlternate
                    ? NSEvent.ModifierFlags(rawValue: UInt(entry.setting.modifiers.rawValue)) : []
                item.isAlternate = entry.isAlternate
                menu.addItem(item)
            }
        }
        button.menu = menu
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.onChoose = onChoose
        if let cell = button.cell as? NSPopUpButtonCell, cell.menuItem?.title != setting.title {
            cell.menuItem = NSMenuItem(title: setting.title, action: nil, keyEquivalent: "")
        }
        // The checkmark, and where the open menu lines up. Nothing for a value
        // the menu does not offer.
        let wanted = setting.normalized
        let item = button.menu?.items.first { ($0.representedObject as? CornerSetting)?.normalized == wanted }
        if button.selectedItem !== item { button.select(item) }
        button.toolTip = setting.title
        button.isEnabled = isEnabled
    }

    @MainActor
    final class Coordinator: NSObject {
        var onChoose: (CornerSetting) -> Void = { _ in }

        @objc func chosen(_ item: NSMenuItem) {
            guard let setting = item.representedObject as? CornerSetting else { return }
            // The store publishes on every choice, so the next update puts the
            // closed title and the checkmark on what the Dock ends up with.
            onChoose(setting)
        }
    }
}
