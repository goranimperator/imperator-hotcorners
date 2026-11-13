import AppKit
import HotCornersCore
import SwiftUI

/// Header, corner grid with the disable switch under it, footer. Brandbook 9.1 and 9.2.
struct PopoverContentView: View {
    /// Wider than the brandbook's 340: two columns of pop-ups need 176 pt each
    /// for "Disable Screen Saver" at regular size, and 340 leaves 150.
    static let width: CGFloat = 400
    static let padding: CGFloat = 16
    static let columnSpacing: CGFloat = 12
    static let offOpacity = 0.3
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")!

    @ObservedObject var store: HotCornerStore
    let dismissAction: () -> Void
    let quitAction: () -> Void
    /// Set only by `--render-preview`, to draw the update row without the network.
    var previewUpdate: UpdateChecker.Release? = nil

    /// Drawn once. The header is rebuilt on every state change and the glyph
    /// never varies.
    private static let headerIcon = StatusItemIcon.make(size: 16)

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                if let problem = store.problem { notice(for: problem) }
                // Until the Dock has answered once there is nothing true to show,
                // and placeholder corners would read as real ones.
                if store.hasReadDock {
                    cornerGrid
                    disableRow
                }
            }
            .padding(Self.padding)
            AppUpdateRow(update: previewUpdate ?? UpdateChecker.shared.available)
            Divider()
            footerView
        }
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(AppColors.popoverBackground)
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 8) {
            // Brandbook 16.1 keeps the sigil out of the header; this is the
            // app's own glyph, the same one the menu bar item draws.
            Image(nsImage: Self.headerIcon)
                .renderingMode(.template)
                .foregroundStyle(.primary)

            Text("Imperator HotCorners")
                .font(.headline)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// The switch acts on all four corners, so it sits under them with the
    /// action in its name instead of in the header. On means every corner is
    /// off; the store's own flag runs the other way.
    private var disableRow: some View {
        HStack(spacing: 6) {
            Text("Disable HotCorners")
                // Brandbook 3.2: labels are 13 pt regular.
                .font(.system(size: 13))
            Toggle("", isOn: Binding(get: { !store.isEnabled }, set: { store.setEnabled(!$0) }))
                .brandSwitch()
                .disabled(!store.canEdit)
                .accessibilityLabel("Disable HotCorners")
            Spacer(minLength: 0)
        }
    }

    // The grid mirrors the screen: a pop-up sits where its corner is.
    private var cornerGrid: some View {
        Grid(horizontalSpacing: Self.columnSpacing, verticalSpacing: 8) {
            GridRow {
                popUp(.topLeft)
                popUp(.topRight)
            }
            GridRow {
                popUp(.bottomLeft)
                popUp(.bottomRight)
            }
        }
        // With the corners disabled, the grid fades as one. It all stays usable,
        // so corners can be set up before the switch goes off again.
        .opacity(store.isEnabled ? 1 : Self.offOpacity)
    }

    private func popUp(_ corner: Corner) -> some View {
        CornerPopUp(corner: corner,
                    setting: store.layout[corner],
                    isEnabled: store.canEdit) { store.choose($0, for: corner) }
            .frame(width: CornerPopUp.columnWidth)
    }

    @ViewBuilder
    private func notice(for problem: HotCornerStore.Problem) -> some View {
        switch problem {
        case .apiMissing:
            noticeBox(title: "Hot corners can\u{2019}t be changed here",
                      body: "This version of macOS doesn\u{2019}t let other apps change hot corners. "
                          + "You can still set them in System Settings.",
                      buttonTitle: "Open Desktop & Dock Settings") { NSWorkspace.shared.open(Self.settingsURL) }
        case .dockNotResponding:
            noticeBox(title: "Can\u{2019}t read hot corners",
                      body: "The Dock didn\u{2019}t answer. It usually comes back within a few seconds.",
                      buttonTitle: "Try Again") { store.refresh() }
        case .writeFailed(let corner):
            noticeBox(title: "The \(corner.shortName) corner didn\u{2019}t change",
                      body: "The Dock kept the old setting. Try again, or set it in System Settings.",
                      buttonTitle: "Open Desktop & Dock Settings") { NSWorkspace.shared.open(Self.settingsURL) }
        }
    }

    /// Text is `.primary` and `.secondary`, not brand red: red on this panel is
    /// below the 4.5:1 caption text needs. The action is a system bordered button.
    private func noticeBox(title: String, body: String, buttonTitle: String,
                           action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footerView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                LaunchAtLoginToggle()

                Spacer()

                // The panel sits at the pop-up menu level, above ordinary windows,
                // so it closes first or the About panel would open behind it.
                HoverButton {
                    dismissAction()
                    AboutPanel.show()
                } label: {
                    Text("About")
                        .font(.caption)
                }
                .help("About Imperator HotCorners")

                HoverButton(action: quitAction) {
                    Text("Quit")
                        .font(.caption)
                }
            }
            UpdateCheckRow()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

/// A newer release of the app itself, from `UpdateChecker`. It sits outside the
/// grid that fades while the corners are disabled, so it reads at full strength
/// either way, and opens the release page: installing stays manual. Takes the
/// release as a value so `--render-preview` can draw it without the network.
struct AppUpdateRow: View {
    let update: UpdateChecker.Release?

    var body: some View {
        if let update {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.brand)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Version \(update.version) is out")
                            .font(.system(size: 12, weight: .medium))
                        Text("You have \(UpdateChecker.currentVersion)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Download") { UpdateChecker.open(update.page) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }
}

/// The footer's second row: the daily check's switch, its last result, and
/// Check Now, which runs even with the switch off because it is asked for.
/// The panel has no settings window, so this is where they live.
struct UpdateCheckRow: View {
    @AppStorage(UpdateChecker.enabledKey) private var checkForUpdates = true

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("Check for updates")
                    .font(.caption)
                    .foregroundStyle(.primary)
                Toggle("", isOn: $checkForUpdates)
                    .brandSwitch()
                    .onChange(of: checkForUpdates) { _, on in
                        if on { UpdateChecker.shared.checkIfDue() }
                    }
            }
            .hoverDimmed()

            Spacer()

            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HoverButton(action: { Task { await UpdateChecker.shared.check() } }) {
                Text("Check Now")
                    .font(.caption)
            }
            .disabled(UpdateChecker.shared.status == .checking)
        }
    }

    /// Short, to fit beside the switch; nothing while the row above shows a
    /// newer version.
    private var status: String {
        switch UpdateChecker.shared.status {
        case .idle, .available: return ""
        case .checking: return "Checking\u{2026}"
        case .upToDate: return "Up to date"
        case .failed: return "Could not reach GitHub"
        }
    }
}
