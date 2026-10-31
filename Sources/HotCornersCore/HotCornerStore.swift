import Combine
import Foundation

/// Where the off-state snapshot is kept. `UserDefaults` in the app; tests,
/// previews and the debug fake use `InMemoryStorage` so they never touch the
/// real one.
public protocol SnapshotStorage: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: SnapshotStorage {}

public final class InMemoryStorage: SnapshotStorage {
    private var values: [String: Any] = [:]

    public init() {}

    public func data(forKey key: String) -> Data? { values[key] as? Data }
    public func set(_ value: Any?, forKey key: String) { values[key] = value }
    public func removeObject(forKey key: String) { values[key] = nil }
}

/// The state rules of the app. The Dock is the source of truth; the one thing
/// kept here is the snapshot of the corners as they were when the switch went
/// off.
@MainActor
public final class HotCornerStore: ObservableObject {
    public enum Problem: Equatable {
        case apiMissing
        case dockNotResponding
        case writeFailed(Corner)
    }

    /// The remembered corners. `inTransition` is set before the first Dock
    /// write of a switch, in either direction, and cleared once the switch
    /// completes or is fully undone. A record still marked means the Dock may
    /// hold a mix that only this app wrote.
    struct Snapshot: Codable, Equatable {
        var layout: CornerLayout
        var inTransition: Bool
    }

    @Published public private(set) var layout: CornerLayout = .allNoAction
    @Published public private(set) var isEnabled = true
    @Published public private(set) var problem: Problem?
    /// False until the Dock has answered once. Until then `layout` and
    /// `isEnabled` are placeholders, not what the Dock has, and are not shown.
    @Published public private(set) var hasReadDock = false

    public var canEdit: Bool { hasReadDock && problem != .apiMissing && problem != .dockNotResponding }

    nonisolated public static let snapshotKey = "disabledSnapshot"

    private let backend: HotCornerBackend?
    private let defaults: SnapshotStorage

    public init(backend: HotCornerBackend?, defaults: SnapshotStorage = UserDefaults.standard) {
        self.backend = backend
        self.defaults = defaults
        if backend == nil { problem = .apiMissing }
    }

    /// Reads the Dock and sets the switch and the shown corners from it.
    public func refresh() {
        guard let dock = readDock() else { return }
        problem = nil
        reconcile(with: dock)
    }

    public func choose(_ setting: CornerSetting, for corner: Corner) {
        guard canEdit, let backend else { return }
        if !isEnabled {
            // Off: everything stays usable, and edits what comes back on.
            layout[corner] = setting
            saveSnapshot(Snapshot(layout: layout, inTransition: loadSnapshot()?.inTransition ?? false))
            return
        }
        // Compare with the Dock, not the last refresh: Settings may have changed
        // the corner while the panel was open.
        guard let dock = readDock() else { return }
        layout = dock
        if dock[corner].normalized == setting.normalized {
            problem = nil
            return
        }
        do {
            // The backend verifies by reading back, so success means the Dock has it.
            try backend.write(setting, to: corner)
            layout[corner] = setting.normalized
            problem = nil
        } catch {
            fail(error, at: corner)
            if problem != .dockNotResponding, let now = try? backend.read() { layout = now }
        }
    }

    public func setEnabled(_ enabled: Bool) {
        guard canEdit, let backend, enabled != isEnabled, let dock = readDock() else { return }
        let remembered = enabled ? (loadSnapshot()?.layout ?? dock) : dock
        let target = enabled ? remembered : .allNoAction
        // Saved before the first write, so no failure, crash or kill in the middle
        // can lose the corners.
        saveSnapshot(Snapshot(layout: remembered, inTransition: true))

        var written: [Corner] = []
        for corner in Corner.allCases where target[corner].normalized != dock[corner].normalized {
            do {
                try backend.write(target[corner], to: corner)
                written.append(corner)
            } catch {
                fail(error, at: corner)
                // A Dock that does not answer gets no more calls, each of which
                // could block for 3 s. The record stays marked, so the next
                // refresh tells this app's partial writes from Settings changes.
                if problem == .dockNotResponding { return }
                undo(written + [corner], to: dock, remembered: remembered, switchingOn: enabled)
                return
            }
        }

        if enabled {
            clearSnapshot()
        } else {
            saveSnapshot(Snapshot(layout: remembered, inTransition: false))
        }
        isEnabled = enabled
        layout = remembered
        problem = nil
    }

    /// Sets the switch and the shown corners from the Dock and the snapshot.
    /// With a settled snapshot any active corner means Settings changed it, and
    /// Settings wins. With a snapshot still in transition, active corners equal
    /// to the snapshot are this app's own partial writes and keep it off; switching
    /// on finishes the job.
    private func reconcile(with dock: CornerLayout) {
        guard let snapshot = loadSnapshot() else {
            isEnabled = true
            layout = dock
            return
        }
        let settingsChanged = Corner.allCases.contains { corner in
            dock[corner].action.isActive
                && (!snapshot.inTransition || dock[corner].normalized != snapshot.layout[corner].normalized)
        }
        if settingsChanged {
            clearSnapshot()
            isEnabled = true
            layout = dock
        } else {
            isEnabled = false
            layout = snapshot.layout
        }
    }

    /// Puts back what a failed switch already changed, then reads the Dock so the
    /// panel shows what is really there.
    private func undo(_ corners: [Corner], to dock: CornerLayout, remembered: CornerLayout, switchingOn: Bool) {
        guard let backend else { return }
        // The failed corner too: the Dock may have applied a write that read back stale.
        for corner in corners { try? backend.write(dock[corner], to: corner) }
        let failure = problem
        guard let now = try? backend.read() else {
            problem = .dockNotResponding
            return
        }
        if Corner.allCases.allSatisfy({ now[$0].normalized == dock[$0].normalized }) {
            // Back where the step started.
            if switchingOn {
                saveSnapshot(Snapshot(layout: remembered, inTransition: false))
            } else {
                clearSnapshot()
            }
        }
        // Otherwise the record stays marked in transition and reconcile keeps
        // the user's corners.
        reconcile(with: now)
        problem = failure
    }

    private func readDock() -> CornerLayout? {
        guard let backend else {
            problem = .apiMissing
            return nil
        }
        do {
            let dock = try backend.read()
            hasReadDock = true
            return dock
        } catch {
            problem = .dockNotResponding
            return nil
        }
    }

    private func fail(_ error: Error, at corner: Corner) {
        problem = (error as? DockError)?.isNoReply == true ? .dockNotResponding : .writeFailed(corner)
    }

    private func loadSnapshot() -> Snapshot? {
        guard let data = defaults.data(forKey: Self.snapshotKey) else { return nil }
        let decoder = JSONDecoder()
        if let snapshot = try? decoder.decode(Snapshot.self, from: data) { return snapshot }
        // Builds before the transition marker stored the bare layout.
        if let layout = try? decoder.decode(CornerLayout.self, from: data) {
            return Snapshot(layout: layout, inTransition: false)
        }
        clearSnapshot()
        return nil
    }

    private func saveSnapshot(_ snapshot: Snapshot) {
        if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: Self.snapshotKey) }
    }

    private func clearSnapshot() { defaults.removeObject(forKey: Self.snapshotKey) }
}
