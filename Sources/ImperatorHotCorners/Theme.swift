import AppKit
import ServiceManagement
import SwiftUI

enum AppColors {
    static let brand = Color(red: 0xa0 / 255.0, green: 0x18 / 255.0, blue: 0x18 / 255.0)
    static let brandFaded = brand.opacity(0.25)
    static let accent = Color(red: 0.43, green: 0.05, blue: 0.05)
    static let error = Color(red: 0.9, green: 0.3, blue: 0.3)
    /// Brandbook 2.3: the panel content background overlay.
    static let popoverBackground = Color.black.opacity(0.15)

    // AppKit colors, for pure NSView code.
    static let brandNS = NSColor(red: 0xa0 / 255.0, green: 0x18 / 255.0, blue: 0x18 / 255.0, alpha: 1.0)
    static let backgroundNS = NSColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1)
}

struct LaunchAtLoginToggle: View {
    @State private var isEnabled = LaunchAtLoginToggle.registered

    private static var registered: Bool { SMAppService.mainApp.status == .enabled }

    var body: some View {
        HStack(spacing: 6) {
            Text("Open at Login")
                .font(.caption)
                .foregroundStyle(.primary)
            // A binding with an action, not an onChange revert: resetting the
            // switch after a failed register would fire onChange again and
            // unregister what nobody asked to remove.
            Toggle("", isOn: Binding(get: { isEnabled }, set: { apply($0) }))
                .brandSwitch()
        }
        .hoverDimmed()
        // The panel's content lives as long as the app, and Login Items can change
        // in System Settings meanwhile. The panel activates the app on every open.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isEnabled = Self.registered
        }
    }

    private func apply(_ on: Bool) {
        let service = SMAppService.mainApp
        do {
            if on { try service.register() } else { try service.unregister() }
        } catch {}
        // A login item switched off in System Settings needs the user's approval there.
        if on, service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        // Show what macOS did, not what was asked.
        isEnabled = Self.registered
    }
}

struct HoverButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .hoverDimmed()
    }
}

/// Full opacity under the pointer, 45% at rest.
private struct HoverDimmed: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .opacity(isHovered ? 1.0 : 0.45)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

extension View {
    /// Brandbook 7.2's switch: the system switch scaled to 0.55, brand tint, no
    /// label, and no frame, since a frame would only add invisible padding.
    ///
    /// Scaling leaves the layout frame at full size, 54 pt wide, so a switch
    /// scaled from its centre sits 12 pt inside whatever it is aligned to. At the
    /// right end of a row, `anchor: .trailing` puts its drawn edge on the row's.
    func brandSwitch(anchor: UnitPoint = .center) -> some View {
        toggleStyle(.switch)
            .scaleEffect(0.55, anchor: anchor)
            .tint(AppColors.brand)
            .labelsHidden()
    }

    func hoverDimmed() -> some View {
        modifier(HoverDimmed())
    }
}
