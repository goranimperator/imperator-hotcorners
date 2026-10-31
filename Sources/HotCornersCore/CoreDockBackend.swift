import Foundation

/// Reads and writes hot corners the way System Settings does: two private
/// HIServices calls that go straight to the Dock, so a change lands at once and
/// the Dock is never restarted. Loaded with `dlsym` so a macOS without them
/// still launches, and the app shows a notice instead.
public final class CoreDockBackend: HotCornerBackend {
    public typealias GetFunction = (UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
    /// (action, corner code, modifiers): System Settings' argument order.
    public typealias SetFunction = (Int32, Int32, Int32) -> Int32

    private typealias CGet = @convention(c) (UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
    private typealias CSet = @convention(c) (Int32, Int32, Int32) -> Int32
    private static let library = "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"

    private let get: GetFunction
    private let set: SetFunction
    private let readBackTimeout: TimeInterval
    private let pollInterval: TimeInterval

    /// After a set, the Dock is read until it shows the change or
    /// `readBackTimeout` runs out. The setter's status comes back in the Dock's
    /// reply, so the first read normally matches and nothing sleeps; the short
    /// poll covers a Dock that applies the change after it replies.
    public init(get: @escaping GetFunction, set: @escaping SetFunction,
                readBackTimeout: TimeInterval = 0.3, pollInterval: TimeInterval = 0.02) {
        self.get = get
        self.set = set
        self.readBackTimeout = readBackTimeout
        self.pollInterval = pollInterval
    }

    /// The corner numbers the Dock's setter expects. Measured with
    /// `scripts/calibrate-dock.swift --run` on 2026-10-31, macOS 27.2 (26B123):
    /// top left 0, top right 1, bottom left 2, bottom right 3, argument order
    /// (action, corner, modifiers).
    public static func cornerCode(_ corner: Corner) -> Int32 {
        switch corner {
        case .topLeft: 0
        case .topRight: 1
        case .bottomLeft: 2
        case .bottomRight: 3
        }
    }

    /// Both functions, or nil when either is missing.
    public static func system() -> CoreDockBackend? {
        guard let cGet = getter(), let cSet = setter() else { return nil }
        return CoreDockBackend(get: { cGet($0, $1) }, set: { cSet($0, $1, $2) })
    }

    /// The getter alone, for checks that must never be able to write. Its
    /// `write` always fails without calling the Dock.
    public static func reader() -> CoreDockBackend? {
        guard let cGet = getter() else { return nil }
        return CoreDockBackend(get: { cGet($0, $1) }, set: { _, _, _ in -1 })
    }

    private static func symbol(_ name: String) -> UnsafeMutableRawPointer? {
        guard let handle = dlopen(library, RTLD_LAZY) else { return nil }
        return dlsym(handle, name)
    }

    private static func getter() -> CGet? {
        symbol("CoreDockGetExposeCornerActionsWithModifiers").map { unsafeBitCast($0, to: CGet.self) }
    }

    private static func setter() -> CSet? {
        symbol("CoreDockSetExposeCornerActionWithModifier").map { unsafeBitCast($0, to: CSet.self) }
    }

    public func read() throws -> CornerLayout {
        // The Dock's own defaults: "-" and no modifiers.
        var actions = [Int32](repeating: 1, count: 4)
        var modifiers = [Int32](repeating: 0, count: 4)
        let status = get(&actions, &modifiers)
        if status != 0 { throw DockError.status(status) }
        return CornerLayout(dockActions: actions, dockModifiers: modifiers)
    }

    public func write(_ setting: CornerSetting, to corner: Corner) throws {
        let wanted = setting.normalized
        let status = set(wanted.action.rawValue, Self.cornerCode(corner), wanted.modifiers.rawValue)
        if status != 0 { throw DockError.status(status) }
        // Trust the read-back, not the status.
        let deadline = Date().addingTimeInterval(readBackTimeout)
        while true {
            if try read()[corner].normalized == wanted { return }
            if Date() >= deadline { throw DockError.notApplied(corner) }
            Thread.sleep(forTimeInterval: pollInterval)
        }
    }
}
